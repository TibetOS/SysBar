import Foundation

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0.0 - 1.0
    let perCoreUsage: [Double]      // per-core 0.0 - 1.0
    let coreCount: Int
}

struct RAMMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    var usagePercent: Double { Double(used) / Double(total) }
}

struct GPUMetrics: Sendable {
    let utilization: Double         // 0.0 - 1.0
    let vramUsed: UInt64?           // bytes, nil if unavailable
    let vramTotal: UInt64?          // bytes, nil if unavailable
}

struct DiskMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    var usagePercent: Double { Double(used) / Double(total) }
}

struct NetworkMetrics: Sendable {
    let bytesPerSecUp: UInt64
    let bytesPerSecDown: UInt64
}

struct BatteryMetrics: Sendable {
    let level: Int                  // 0-100
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool
}

struct SystemSnapshot: Sendable {
    let cpu: CPUMetrics
    let ram: RAMMetrics
    let gpu: GPUMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics
    let timestamp: Date
}
