import SwiftUI

struct FloatingView: View {
    let state: AppState

    private var uptime: String {
        let secs = ProcessInfo.processInfo.systemUptime
        let days = Int(secs) / 86400
        let hours = (Int(secs) % 86400) / 3600
        let mins = (Int(secs) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h \(mins)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header
            HStack(spacing: 4) {
                Text("SysBar")
                    .font(.system(.caption2, weight: .semibold))
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("up \(uptime)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: { state.toggleFloating() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if let snap = state.snapshot {
                // CPU with spark-line
                HStack(spacing: 6) {
                    Text("CPU")
                        .font(.system(.caption2, design: .monospaced))
                        .frame(width: 28, alignment: .leading)
                        .foregroundStyle(.secondary)
                    SparkLine(values: state.cpuHistory)
                        .frame(width: 60, height: 12)
                    Spacer()
                    Text("\(MetricFormatter.percent(snap.cpu.totalUsage)) · \(snap.cpu.coreCount) cores")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 16)

                // RAM
                metricBar("RAM", value: snap.ram.usagePercent,
                          detail: "\(MetricFormatter.bytes(snap.ram.used)) / \(MetricFormatter.bytes(snap.ram.total))")

                // GPU
                metricBar("GPU", value: snap.gpu.utilization,
                          detail: MetricFormatter.percent(snap.gpu.utilization))

                // Disk
                metricBar("Disk", value: snap.disk.usagePercent,
                          detail: "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")

                Divider().padding(.vertical, 1)

                // Network + Battery on compact rows
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.blue)
                        Text(MetricFormatter.speed(snap.network.bytesPerSecUp))
                            .font(.system(.caption2, design: .monospaced))
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.green)
                        Text(MetricFormatter.speed(snap.network.bytesPerSecDown))
                            .font(.system(.caption2, design: .monospaced))
                    }
                    Spacer()
                    if snap.battery.hasBattery {
                        HStack(spacing: 3) {
                            if snap.battery.isCharging {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.yellow)
                            }
                            Text("\(snap.battery.level)%")
                                .font(.system(.caption2, design: .monospaced))
                            Image(systemName: "battery.100percent")
                                .font(.system(size: 9))
                                .foregroundStyle(batteryColor(snap.battery.level))
                        }
                    }
                }
                .frame(height: 14)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    ProgressView().controlSize(.mini)
                    Text("Loading...")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(width: 250)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metric bar

    private func metricBar(_ label: String, value: Double, detail: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(value))
                        .frame(width: geo.size.width * min(max(CGFloat(value), 0), 1))
                }
            }
            .frame(height: 6)

            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 16)
    }

    private func barColor(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }

    private func batteryColor(_ level: Int) -> Color {
        if level <= 15 { return .red }
        if level <= 30 { return .orange }
        return .green
    }
}
