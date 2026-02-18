import Foundation
import Darwin
import IOKit

actor SystemMonitor {

    private static let hostPageSize: UInt64 = {
        var size: vm_size_t = 0
        var len = MemoryLayout<vm_size_t>.size
        sysctlbyname("hw.pagesize", &size, &len, nil, 0)
        return UInt64(size)
    }()

    // Cached system info (doesn't change)
    private static let cachedChipName: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [UInt8](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        if let idx = buffer.firstIndex(of: 0) { buffer.removeSubrange(idx...) }
        return String(decoding: buffer, as: UTF8.self)
    }()

    private static let cachedMacOSVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    private static let cachedHostname: String = {
        ProcessInfo.processInfo.hostName
    }()

    private static let cachedMemorySize: String = {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }()

    // MARK: - State for delta calculations

    private var previousCPUTicks: [[UInt32]] = []
    private var previousNetworkBytes: (sent: UInt64, received: UInt64)?
    private var previousNetworkTimestamp: Date?

    // MARK: - CPU

    func collectCPU() -> CPUMetrics {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUMetrics(totalUsage: 0, perCoreUsage: [], coreCount: 0)
        }

        defer {
            let size = vm_size_t(
                Int(processorInfoCount) * MemoryLayout<integer_t>.size
            )
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let coreCount = Int(processorCount)
        var currentTicks: [[UInt32]] = []

        for core in 0..<coreCount {
            let offset = Int32(core) * CPU_STATE_MAX
            let user = UInt32(bitPattern: info[Int(offset + CPU_STATE_USER)])
            let system = UInt32(bitPattern: info[Int(offset + CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: info[Int(offset + CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: info[Int(offset + CPU_STATE_NICE)])
            currentTicks.append([user, system, idle, nice])
        }

        guard !previousCPUTicks.isEmpty,
              previousCPUTicks.count == coreCount else {
            previousCPUTicks = currentTicks
            return CPUMetrics(
                totalUsage: 0,
                perCoreUsage: Array(repeating: 0, count: coreCount),
                coreCount: coreCount
            )
        }

        var perCoreUsage: [Double] = []
        var totalUsed: UInt64 = 0
        var totalAll: UInt64 = 0

        for core in 0..<coreCount {
            let prev = previousCPUTicks[core]
            let curr = currentTicks[core]

            let deltaUser = UInt64(curr[0] &- prev[0])
            let deltaSystem = UInt64(curr[1] &- prev[1])
            let deltaIdle = UInt64(curr[2] &- prev[2])
            let deltaNice = UInt64(curr[3] &- prev[3])

            let used = deltaUser + deltaSystem + deltaNice
            let total = used + deltaIdle

            let usage = total > 0 ? Double(used) / Double(total) : 0
            perCoreUsage.append(min(max(usage, 0), 1))

            totalUsed += used
            totalAll += total
        }

        previousCPUTicks = currentTicks

        let totalUsage = totalAll > 0 ? Double(totalUsed) / Double(totalAll) : 0
        return CPUMetrics(
            totalUsage: min(max(totalUsage, 0), 1),
            perCoreUsage: perCoreUsage,
            coreCount: coreCount
        )
    }

    // MARK: - RAM

    func collectRAM() -> RAMMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { intPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMMetrics(used: 0, total: 0, appMemory: 0, wired: 0, compressed: 0)
        }

        let pageSize = UInt64(Self.hostPageSize)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired
        let total = ProcessInfo.processInfo.physicalMemory

        return RAMMetrics(
            used: used,
            total: total,
            appMemory: active,
            wired: wired,
            compressed: compressed
        )
    }

    // MARK: - GPU

    func collectGPU() -> GPUMetrics {
        guard let matching = IOServiceMatching("AGXAccelerator") else {
            return GPUMetrics(utilization: 0, vramUsed: nil, vramTotal: nil)
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &iterator
        )

        guard result == KERN_SUCCESS else {
            return GPUMetrics(utilization: 0, vramUsed: nil, vramTotal: nil)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return GPUMetrics(utilization: 0, vramUsed: nil, vramTotal: nil)
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let propResult = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )

        guard propResult == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return GPUMetrics(utilization: 0, vramUsed: nil, vramTotal: nil)
        }

        var utilization: Double = 0
        if let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
            if let gpuUtil = perfStats["Device Utilization %"] as? NSNumber {
                utilization = gpuUtil.doubleValue / 100.0
            } else if let gpuUtil = perfStats["GPU Activity(%)"] as? NSNumber {
                utilization = gpuUtil.doubleValue / 100.0
            }
        }

        return GPUMetrics(
            utilization: min(max(utilization, 0), 1),
            vramUsed: nil,
            vramTotal: nil
        )
    }

    // MARK: - Disk

    func collectDisk() -> DiskMetrics {
        var stat = statvfs()
        guard statvfs("/", &stat) == 0 else {
            return DiskMetrics(used: 0, total: 0)
        }

        let blockSize = UInt64(stat.f_frsize)
        let total = UInt64(stat.f_blocks) * blockSize
        let available = UInt64(stat.f_bavail) * blockSize
        let used = total - available

        return DiskMetrics(used: used, total: total)
    }

    // MARK: - Network

    func collectNetwork() -> NetworkMetrics {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return NetworkMetrics(bytesPerSecUp: 0, bytesPerSecDown: 0,
                                 totalSent: 0, totalReceived: 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = current {
            let ifaAddr = addr.pointee

            if ifaAddr.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifaAddr.ifa_name)

                if name != "lo0" {
                    if let data = ifaAddr.ifa_data {
                        let networkData = data.assumingMemoryBound(
                            to: if_data.self
                        )
                        totalSent += UInt64(networkData.pointee.ifi_obytes)
                        totalReceived += UInt64(networkData.pointee.ifi_ibytes)
                    }
                }
            }

            current = ifaAddr.ifa_next
        }

        let now = Date()

        guard let prevBytes = previousNetworkBytes,
              let prevTime = previousNetworkTimestamp else {
            previousNetworkBytes = (sent: totalSent, received: totalReceived)
            previousNetworkTimestamp = now
            return NetworkMetrics(bytesPerSecUp: 0, bytesPerSecDown: 0,
                                 totalSent: totalSent, totalReceived: totalReceived)
        }

        let elapsed = now.timeIntervalSince(prevTime)
        guard elapsed > 0 else {
            return NetworkMetrics(bytesPerSecUp: 0, bytesPerSecDown: 0,
                                 totalSent: totalSent, totalReceived: totalReceived)
        }

        let deltaSent = totalSent >= prevBytes.sent
            ? totalSent - prevBytes.sent : 0
        let deltaReceived = totalReceived >= prevBytes.received
            ? totalReceived - prevBytes.received : 0

        let bytesPerSecUp = UInt64(Double(deltaSent) / elapsed)
        let bytesPerSecDown = UInt64(Double(deltaReceived) / elapsed)

        previousNetworkBytes = (sent: totalSent, received: totalReceived)
        previousNetworkTimestamp = now

        return NetworkMetrics(
            bytesPerSecUp: bytesPerSecUp,
            bytesPerSecDown: bytesPerSecDown,
            totalSent: totalSent,
            totalReceived: totalReceived
        )
    }

    // MARK: - Battery

    func collectBattery() -> BatteryMetrics {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return BatteryMetrics(
                level: 0, isCharging: false,
                isPluggedIn: false, hasBattery: false,
                cycleCount: 0, health: 0, temperature: 0
            )
        }

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, matching
        )
        guard service != 0 else {
            return BatteryMetrics(
                level: 0, isCharging: false,
                isPluggedIn: false, hasBattery: false,
                cycleCount: 0, health: 0, temperature: 0
            )
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service, &properties, kCFAllocatorDefault, 0
        )

        guard result == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return BatteryMetrics(
                level: 0, isCharging: false,
                isPluggedIn: false, hasBattery: false,
                cycleCount: 0, health: 0, temperature: 0
            )
        }

        let currentCapacity = dict["CurrentCapacity"] as? Int ?? 0
        let maxCapacity = dict["MaxCapacity"] as? Int ?? 100
        let designCapacity = dict["DesignCapacity"] as? Int ?? maxCapacity
        let isCharging = dict["IsCharging"] as? Bool ?? false
        let externalConnected = dict["ExternalConnected"] as? Bool ?? false
        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let tempRaw = dict["Temperature"] as? Int ?? 0

        let level = maxCapacity > 0
            ? Int(Double(currentCapacity) / Double(maxCapacity) * 100)
            : 0

        let health = designCapacity > 0
            ? Int(Double(maxCapacity) / Double(designCapacity) * 100)
            : 0

        // Temperature is in centi-degrees Celsius
        let temperature = Double(tempRaw) / 100.0

        return BatteryMetrics(
            level: min(max(level, 0), 100),
            isCharging: isCharging,
            isPluggedIn: externalConnected,
            hasBattery: true,
            cycleCount: cycleCount,
            health: min(health, 100),
            temperature: temperature
        )
    }

    // MARK: - System Info

    func collectSystemInfo() -> SystemInfo {
        let thermal: String = switch ProcessInfo.processInfo.thermalState {
        case .nominal: "Normal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }

        return SystemInfo(
            chipName: Self.cachedChipName,
            macOSVersion: Self.cachedMacOSVersion,
            hostname: Self.cachedHostname,
            memorySize: Self.cachedMemorySize,
            thermalState: thermal
        )
    }

    // MARK: - Full Snapshot

    func collectSnapshot() -> SystemSnapshot {
        SystemSnapshot(
            cpu: collectCPU(),
            ram: collectRAM(),
            gpu: collectGPU(),
            disk: collectDisk(),
            network: collectNetwork(),
            battery: collectBattery(),
            info: collectSystemInfo(),
            timestamp: Date()
        )
    }
}
