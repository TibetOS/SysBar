import SwiftUI

enum MetricColor {
    static func usage(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }

    static func battery(_ level: Int) -> Color {
        if level <= 15 { return .red }
        if level <= 30 { return .orange }
        return .green
    }

    static func health(_ cpu: Double, _ ram: Double) -> Color {
        let worst = max(cpu, ram)
        if worst > 0.85 { return .red }
        if worst > 0.60 { return .yellow }
        return .green
    }
}

enum MetricFormatter {
    static func bytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(value) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    static func speed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec >= 1_073_741_824 {
            return String(format: "%.1f GB/s", Double(bytesPerSec) / 1_073_741_824)
        } else if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", Double(bytesPerSec) / 1024)
        }
        return "\(bytesPerSec) B/s"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
