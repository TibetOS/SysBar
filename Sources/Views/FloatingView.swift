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
            headerRow

            if let snap = state.snapshot {
                if state.isFloatingExpanded {
                    expandedContent(snap)
                } else {
                    compactContent(snap)
                }
            } else {
                loadingRow
            }
        }
        .padding(state.isFloatingExpanded ? 14 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 4) {
            Text("SysBar")
                .font(.system(state.isFloatingExpanded ? .caption : .caption2, weight: .semibold))
            Text("·")
                .foregroundStyle(.quaternary)
            Text("up \(uptime)")
                .font(.system(state.isFloatingExpanded ? .caption : .caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: { state.toggleExpanded() }) {
                Image(systemName: state.isFloatingExpanded
                      ? "rectangle.compress.vertical"
                      : "rectangle.expand.vertical")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(state.isFloatingExpanded ? "Compact view" : "Expanded view")

            Button(action: { state.toggleFloating() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Compact View

    @ViewBuilder
    private func compactContent(_ snap: SystemSnapshot) -> some View {
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

        metricBar("RAM", value: snap.ram.usagePercent,
                  detail: "\(MetricFormatter.bytes(snap.ram.used)) / \(MetricFormatter.bytes(snap.ram.total))")
        metricBar("GPU", value: snap.gpu.utilization,
                  detail: MetricFormatter.percent(snap.gpu.utilization))
        metricBar("Disk", value: snap.disk.usagePercent,
                  detail: "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")

        Divider().padding(.vertical, 1)
        networkBatteryRow(snap)
    }

    // MARK: - Expanded View

    @ViewBuilder
    private func expandedContent(_ snap: SystemSnapshot) -> some View {
        // CPU with spark-line
        HStack(spacing: 8) {
            Text("CPU")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(.secondary)
            SparkLine(values: state.cpuHistory)
                .frame(height: 16)
            Text("\(MetricFormatter.percent(snap.cpu.totalUsage)) · \(snap.cpu.coreCount) cores")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .frame(height: 20)

        expandedMetricBar("RAM", value: snap.ram.usagePercent,
                          detail: "\(MetricFormatter.bytes(snap.ram.used)) / \(MetricFormatter.bytes(snap.ram.total))")
        expandedMetricBar("GPU", value: snap.gpu.utilization,
                          detail: MetricFormatter.percent(snap.gpu.utilization))
        expandedMetricBar("Disk", value: snap.disk.usagePercent,
                          detail: "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")

        Divider().padding(.vertical, 2)
        networkBatteryRow(snap)

        Divider().padding(.vertical, 2)

        // Disk Breakdown
        diskBreakdownSection
    }

    // MARK: - Shared Components

    private func networkBatteryRow(_ snap: SystemSnapshot) -> some View {
        let fontSize: CGFloat = state.isFloatingExpanded ? 8 : 7
        let textStyle: Font.TextStyle = state.isFloatingExpanded ? .caption : .caption2
        return HStack(spacing: 12) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.blue)
                Text(MetricFormatter.speed(snap.network.bytesPerSecUp))
                    .font(.system(textStyle, design: .monospaced))
            }
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.green)
                Text(MetricFormatter.speed(snap.network.bytesPerSecDown))
                    .font(.system(textStyle, design: .monospaced))
            }
            Spacer()
            if snap.battery.hasBattery {
                HStack(spacing: 3) {
                    if snap.battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: fontSize))
                            .foregroundStyle(.yellow)
                    }
                    Text("\(snap.battery.level)%")
                        .font(.system(textStyle, design: .monospaced))
                    Image(systemName: "battery.100percent")
                        .font(.system(size: fontSize + 2))
                        .foregroundStyle(batteryColor(snap.battery.level))
                }
            }
        }
        .frame(height: state.isFloatingExpanded ? 18 : 14)
        .foregroundStyle(.secondary)
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().controlSize(.mini)
            Text("Loading...")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Disk Breakdown

    private var diskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Disk Breakdown")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            if state.isDiskScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning directories...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if state.diskBreakdown.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.diskBreakdown.prefix(10)) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: folderIcon(entry.name))
                            .font(.caption2)
                            .frame(width: 14)
                            .foregroundStyle(.secondary)
                        Text(entry.name)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(MetricFormatter.bytes(entry.size))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 18)
                }
            }
        }
    }

    private func folderIcon(_ name: String) -> String {
        switch name {
        case "Applications": return "app.badge"
        case "Downloads": return "arrow.down.circle"
        case "Documents": return "doc"
        case "Library": return "books.vertical"
        case "Desktop": return "menubar.dock.rectangle"
        case "Pictures": return "photo"
        case "Music": return "music.note"
        case "Movies": return "film"
        case "System & Other": return "gearshape"
        case "Trash": return "trash"
        default: return "folder"
        }
    }

    // MARK: - Metric Bars

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

    private func expandedMetricBar(_ label: String, value: Double, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(value))
                        .frame(width: geo.size.width * min(max(CGFloat(value), 0), 1))
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 20)
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
