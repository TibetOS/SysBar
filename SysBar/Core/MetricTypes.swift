import Foundation

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0.0–1.0
    let perCore: [Double]           // per-core 0.0–1.0
    let coreCount: Int
}

struct RAMMetrics: Sendable {
    let used: UInt64
    let total: UInt64
    let active: UInt64
    let wired: UInt64
    let compressed: UInt64
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct DiskMetrics: Sendable {
    let used: UInt64
    let total: UInt64
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct NetworkMetrics: Sendable {
    let upSpeed: UInt64             // bytes/sec
    let downSpeed: UInt64           // bytes/sec
    let totalSent: UInt64           // bytes since boot
    let totalReceived: UInt64       // bytes since boot
}

struct BatteryMetrics: Sendable {
    let level: Int                  // 0–100
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool
    let cycleCount: Int
    let health: Int                 // 0–100
    let temperature: Double         // celsius
}

struct SystemInfo: Sendable {
    let chipName: String
    let macOSVersion: String
    let hostname: String
    let memorySize: String
}

struct SystemSnapshot: Sendable {
    let cpu: CPUMetrics
    let ram: RAMMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics
    let info: SystemInfo
    let timestamp: Date
}
