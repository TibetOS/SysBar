import Foundation
import Darwin
import IOKit

actor MetricCollector {

    private static let pageSize: UInt64 = {
        var size: vm_size_t = 0
        var len = MemoryLayout<vm_size_t>.size
        sysctlbyname("hw.pagesize", &size, &len, nil, 0)
        return UInt64(size)
    }()

    private static let chipName: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [UInt8](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        if let idx = buffer.firstIndex(of: 0) { buffer.removeSubrange(idx...) }
        return String(decoding: buffer, as: UTF8.self)
    }()

    private static let macOSVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    private static let hostname: String = {
        ProcessInfo.processInfo.hostName
    }()

    private static let memorySize: String = {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return String(format: "%.0f GB", Double(bytes) / 1_073_741_824)
    }()

    private var previousCPUTicks: [[UInt32]] = []
    private var previousNetBytes: (sent: UInt64, recv: UInt64)?
    private var previousNetTime: Date?

    // MARK: - CPU

    func collectCPU() -> CPUMetrics {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &cpuCount, &cpuInfo, &cpuInfoCount
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return CPUMetrics(totalUsage: 0, perCore: [], coreCount: 0)
        }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.size))
        }

        let cores = Int(cpuCount)
        var current: [[UInt32]] = []
        for c in 0..<cores {
            let off = Int32(c) * CPU_STATE_MAX
            current.append([
                UInt32(bitPattern: info[Int(off + CPU_STATE_USER)]),
                UInt32(bitPattern: info[Int(off + CPU_STATE_SYSTEM)]),
                UInt32(bitPattern: info[Int(off + CPU_STATE_IDLE)]),
                UInt32(bitPattern: info[Int(off + CPU_STATE_NICE)])
            ])
        }

        guard !previousCPUTicks.isEmpty, previousCPUTicks.count == cores else {
            previousCPUTicks = current
            return CPUMetrics(totalUsage: 0, perCore: Array(repeating: 0, count: cores), coreCount: cores)
        }

        var perCore: [Double] = []
        var totalUsed: UInt64 = 0, totalAll: UInt64 = 0
        for c in 0..<cores {
            let prev = previousCPUTicks[c], curr = current[c]
            let dU = UInt64(curr[0] &- prev[0])
            let dS = UInt64(curr[1] &- prev[1])
            let dI = UInt64(curr[2] &- prev[2])
            let dN = UInt64(curr[3] &- prev[3])
            let used = dU + dS + dN, total = used + dI
            perCore.append(total > 0 ? min(max(Double(used) / Double(total), 0), 1) : 0)
            totalUsed += used; totalAll += total
        }
        previousCPUTicks = current
        let total = totalAll > 0 ? min(max(Double(totalUsed) / Double(totalAll), 0), 1) : 0
        return CPUMetrics(totalUsage: total, perCore: perCore, coreCount: cores)
    }

    // MARK: - RAM

    func collectRAM() -> RAMMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return RAMMetrics(used: 0, total: 0, active: 0, wired: 0, compressed: 0)
        }
        let ps = Self.pageSize
        let active = UInt64(stats.active_count) * ps
        let wired = UInt64(stats.wire_count) * ps
        let compressed = UInt64(stats.compressor_page_count) * ps
        let used = active + wired
        let total = ProcessInfo.processInfo.physicalMemory
        return RAMMetrics(used: used, total: total, active: active, wired: wired, compressed: compressed)
    }

    // MARK: - Disk

    func collectDisk() -> DiskMetrics {
        var stat = statvfs()
        guard statvfs("/", &stat) == 0 else { return DiskMetrics(used: 0, total: 0) }
        let bs = UInt64(stat.f_frsize)
        let total = UInt64(stat.f_blocks) * bs
        let avail = UInt64(stat.f_bavail) * bs
        return DiskMetrics(used: total - avail, total: total)
    }

    // MARK: - Network

    func collectNetwork() -> NetworkMetrics {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return NetworkMetrics(upSpeed: 0, downSpeed: 0, totalSent: 0, totalReceived: 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var sent: UInt64 = 0, recv: UInt64 = 0
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = cur {
            let ifa = addr.pointee
            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if name != "lo0", let data = ifa.ifa_data {
                    let nd = data.assumingMemoryBound(to: if_data.self)
                    sent += UInt64(nd.pointee.ifi_obytes)
                    recv += UInt64(nd.pointee.ifi_ibytes)
                }
            }
            cur = ifa.ifa_next
        }

        let now = Date()
        guard let prev = previousNetBytes, let prevTime = previousNetTime else {
            previousNetBytes = (sent: sent, recv: recv)
            previousNetTime = now
            return NetworkMetrics(upSpeed: 0, downSpeed: 0, totalSent: sent, totalReceived: recv)
        }

        let elapsed = now.timeIntervalSince(prevTime)
        let up = elapsed > 0 ? UInt64(Double(sent >= prev.sent ? sent - prev.sent : 0) / elapsed) : 0
        let down = elapsed > 0 ? UInt64(Double(recv >= prev.recv ? recv - prev.recv : 0) / elapsed) : 0
        previousNetBytes = (sent: sent, recv: recv)
        previousNetTime = now
        return NetworkMetrics(upSpeed: up, downSpeed: down, totalSent: sent, totalReceived: recv)
    }

    // MARK: - Battery

    func collectBattery() -> BatteryMetrics {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return BatteryMetrics(level: 0, isCharging: false, isPluggedIn: false,
                                  hasBattery: false, cycleCount: 0, health: 0, temperature: 0)
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            return BatteryMetrics(level: 0, isCharging: false, isPluggedIn: false,
                                  hasBattery: false, cycleCount: 0, health: 0, temperature: 0)
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return BatteryMetrics(level: 0, isCharging: false, isPluggedIn: false,
                                  hasBattery: false, cycleCount: 0, health: 0, temperature: 0)
        }

        let cur = dict["CurrentCapacity"] as? Int ?? 0
        let maxCap = dict["MaxCapacity"] as? Int ?? 100
        let design = dict["DesignCapacity"] as? Int ?? maxCap
        let level = maxCap > 0 ? Int(Double(cur) / Double(maxCap) * 100) : 0
        let health = design > 0 ? Int(Double(maxCap) / Double(design) * 100) : 0

        return BatteryMetrics(
            level: min(max(level, 0), 100),
            isCharging: dict["IsCharging"] as? Bool ?? false,
            isPluggedIn: dict["ExternalConnected"] as? Bool ?? false,
            hasBattery: true,
            cycleCount: dict["CycleCount"] as? Int ?? 0,
            health: min(health, 100),
            temperature: Double(dict["Temperature"] as? Int ?? 0) / 100.0
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
        return SystemInfo(chipName: Self.chipName, macOSVersion: Self.macOSVersion,
                          hostname: Self.hostname, memorySize: Self.memorySize + " · " + thermal)
    }

    // MARK: - Snapshot

    func collectSnapshot() -> SystemSnapshot {
        SystemSnapshot(
            cpu: collectCPU(), ram: collectRAM(), disk: collectDisk(),
            network: collectNetwork(), battery: collectBattery(),
            info: collectSystemInfo(), timestamp: Date()
        )
    }
}
