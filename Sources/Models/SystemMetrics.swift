import Foundation

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0.0 - 1.0
    let perCoreUsage: [Double]      // per-core 0.0 - 1.0
    let coreCount: Int
}

struct RAMMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    let appMemory: UInt64           // bytes (active)
    let wired: UInt64               // bytes
    let compressed: UInt64          // bytes
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct GPUMetrics: Sendable {
    let utilization: Double         // 0.0 - 1.0
    let vramUsed: UInt64?           // bytes, nil if unavailable
    let vramTotal: UInt64?          // bytes, nil if unavailable
}

struct DiskMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct NetworkMetrics: Sendable {
    let bytesPerSecUp: UInt64
    let bytesPerSecDown: UInt64
    let totalSent: UInt64           // bytes since boot
    let totalReceived: UInt64       // bytes since boot
}

struct BatteryMetrics: Sendable {
    let level: Int                  // 0-100
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool
    let cycleCount: Int
    let health: Int                 // 0-100 percent
    let temperature: Double         // celsius
}

struct SystemInfo: Sendable {
    let chipName: String
    let macOSVersion: String
    let hostname: String
    let memorySize: String
    let thermalState: String
}

struct SystemSnapshot: Sendable {
    let cpu: CPUMetrics
    let ram: RAMMetrics
    let gpu: GPUMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics
    let info: SystemInfo
    let timestamp: Date
}
