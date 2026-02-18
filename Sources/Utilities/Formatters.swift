import Foundation

enum MetricFormatter {
    static func bytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
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
