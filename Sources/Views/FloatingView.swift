import SwiftUI

struct FloatingView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Button(action: { state.toggleFloating() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let snap = state.snapshot {
                compactMetric("CPU", value: snap.cpu.totalUsage,
                              detail: MetricFormatter.percent(snap.cpu.totalUsage))
                compactMetric("RAM", value: snap.ram.usagePercent,
                              detail: "\(MetricFormatter.bytes(snap.ram.used))/\(MetricFormatter.bytes(snap.ram.total))")
                compactMetric("GPU", value: snap.gpu.utilization,
                              detail: MetricFormatter.percent(snap.gpu.utilization))
                compactMetric("Disk", value: snap.disk.usagePercent,
                              detail: "\(MetricFormatter.bytes(snap.disk.used))/\(MetricFormatter.bytes(snap.disk.total))")

                Divider()

                networkRow(snap.network)
                batteryRow(snap.battery)
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
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compact metric row

    private func compactMetric(_ label: String, value: Double, detail: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 30, alignment: .leading)
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
                .frame(width: 70, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private func networkRow(_ net: NetworkMetrics) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
                Text(MetricFormatter.speed(net.bytesPerSecUp))
                    .font(.system(.caption2, design: .monospaced))
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(MetricFormatter.speed(net.bytesPerSecDown))
                    .font(.system(.caption2, design: .monospaced))
            }
            Spacer()
        }
        .frame(height: 14)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func batteryRow(_ battery: BatteryMetrics) -> some View {
        if battery.hasBattery {
            HStack(spacing: 4) {
                Image(systemName: battery.isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 8))
                    .foregroundStyle(battery.isCharging ? .yellow : .green)
                Text("\(battery.level)%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: 14)
        }
    }

    private func barColor(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }
}
