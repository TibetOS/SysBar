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
        // System Info
        systemInfoSection(snap.info)
        Divider().padding(.vertical, 2)

        // CPU
        expandedCPUSection(snap.cpu)
        Divider().padding(.vertical, 2)

        // RAM
        expandedRAMSection(snap.ram)
        Divider().padding(.vertical, 2)

        // GPU + Disk
        expandedMetricBar("GPU", value: snap.gpu.utilization,
                          detail: MetricFormatter.percent(snap.gpu.utilization))
        expandedMetricBar("Disk", value: snap.disk.usagePercent,
                          detail: "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")

        // Disk Breakdown
        if !state.diskBreakdown.isEmpty || state.isDiskScanning {
            diskBreakdownSection
        }

        Divider().padding(.vertical, 2)

        // Network
        expandedNetworkSection(snap.network)

        // Battery
        if snap.battery.hasBattery {
            Divider().padding(.vertical, 2)
            expandedBatterySection(snap.battery)
        }
    }

    // MARK: - System Info

    private func systemInfoSection(_ info: SystemInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(info.chipName)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(height: 16)

            HStack(spacing: 16) {
                infoTag("macOS \(info.macOSVersion)")
                infoTag(info.memorySize)
                infoTag(info.thermalState)
            }
        }
    }

    private func infoTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Expanded CPU

    @ViewBuilder
    private func expandedCPUSection(_ cpu: CPUMetrics) -> some View {
        HStack(spacing: 8) {
            Text("CPU")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(.secondary)
            SparkLine(values: state.cpuHistory)
                .frame(height: 16)
            Text("\(MetricFormatter.percent(cpu.totalUsage))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .frame(height: 20)

        if !cpu.perCoreUsage.isEmpty {
            coreGrid(cpu.perCoreUsage)
                .padding(.leading, 4)
        }
    }

    private func coreGrid(_ cores: [Double]) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(12), spacing: 3),
            count: min(cores.count, 8)
        )
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(cores.enumerated()), id: \.offset) { idx, usage in
                VStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(coreColor(usage))
                        .frame(width: 12, height: 12)
                    Text("\(idx)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .help("Core \(idx): \(MetricFormatter.percent(usage))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coreColor(_ usage: Double) -> Color {
        if usage > 0.85 { return .red }
        if usage > 0.60 { return .orange }
        if usage > 0.30 { return .yellow }
        return .green
    }

    // MARK: - Expanded RAM

    @ViewBuilder
    private func expandedRAMSection(_ ram: RAMMetrics) -> some View {
        expandedMetricBar("RAM", value: ram.usagePercent,
                          detail: "\(MetricFormatter.bytes(ram.used)) / \(MetricFormatter.bytes(ram.total))")

        HStack(spacing: 12) {
            ramDetail("App", value: ram.appMemory, color: .blue)
            ramDetail("Wired", value: ram.wired, color: .orange)
            ramDetail("Compressed", value: ram.compressed, color: .purple)
        }
        .padding(.leading, 4)
    }

    private func ramDetail(_ label: String, value: UInt64, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label): \(MetricFormatter.bytes(value))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Expanded Network

    private func expandedNetworkSection(_ net: NetworkMetrics) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(MetricFormatter.speed(net.bytesPerSecUp))
                        .font(.system(.caption, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                    Text(MetricFormatter.speed(net.bytesPerSecDown))
                        .font(.system(.caption, design: .monospaced))
                }
                Spacer()
            }
            .frame(height: 18)

            HStack(spacing: 12) {
                Text("Total sent: \(MetricFormatter.bytes(net.totalSent))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("Total recv: \(MetricFormatter.bytes(net.totalReceived))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Expanded Battery

    private func expandedBatterySection(_ battery: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                    .foregroundStyle(batteryColor(battery.level))
                Text("\(battery.level)%")
                    .font(.system(.caption, design: .monospaced, weight: .medium))

                if battery.isCharging {
                    Text("Charging")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                } else if battery.isPluggedIn {
                    Text("Plugged In")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            .frame(height: 18)

            HStack(spacing: 12) {
                infoTag("Health: \(battery.health)%")
                infoTag("Cycles: \(battery.cycleCount)")
                if battery.temperature > 0 {
                    infoTag(String(format: "%.1f°C", battery.temperature))
                }
            }
        }
    }

    // MARK: - Disk Breakdown

    private var diskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Breakdown")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            if state.isDiskScanning {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("Scanning...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(state.diskBreakdown.prefix(8)) { entry in
                    HStack(spacing: 5) {
                        Image(systemName: folderIcon(entry.name))
                            .font(.system(size: 8))
                            .frame(width: 10)
                            .foregroundStyle(.secondary)
                        Text(entry.name)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(MetricFormatter.bytes(entry.size))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 15)
                }
            }
        }
        .padding(.leading, 4)
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

    // MARK: - Shared Network/Battery (compact)

    private func networkBatteryRow(_ snap: SystemSnapshot) -> some View {
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
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().controlSize(.mini)
            Text("Loading...")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
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
