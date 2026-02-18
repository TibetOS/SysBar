import SwiftUI

struct SysBarPanel: View {
    let state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showDiskBreakdown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerSection
            Divider()

            if let snap = state.snapshot {
                metricsSection(snap)
                Divider()
                networkSection(snap.network)
                batterySection(snap.battery)
                Divider()
            } else {
                loadingSection
                Divider()
            }

            floatingToggle
            quitButton
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("SysBar")
                .font(.headline)
            Spacer()
            Text("v0.1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Collecting metrics...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Metrics

    @ViewBuilder
    private func metricsSection(_ snap: SystemSnapshot) -> some View {
        cpuSection(snap.cpu)
        ramRow(snap.ram)
        gpuRow(snap.gpu)
        diskSection(snap.disk)
    }

    // MARK: - CPU

    @ViewBuilder
    private func cpuSection(_ cpu: CPUMetrics) -> some View {
        MetricRow(
            label: "CPU",
            icon: "cpu",
            value: cpu.totalUsage,
            detail: MetricFormatter.percent(cpu.totalUsage)
        )

        if !cpu.perCoreUsage.isEmpty {
            coreGrid(cpu.perCoreUsage)
                .padding(.leading, 24)
                .padding(.bottom, 2)
        }
    }

    private func coreGrid(_ cores: [Double]) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(10), spacing: 4),
            count: min(cores.count, 8)
        )

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(cores.enumerated()), id: \.offset) { _, usage in
                RoundedRectangle(cornerRadius: 2)
                    .fill(coreColor(for: usage))
                    .frame(width: 10, height: 10)
                    .help(MetricFormatter.percent(usage))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coreColor(for usage: Double) -> Color {
        if usage > 0.85 { return .red }
        if usage > 0.60 { return .orange }
        if usage > 0.30 { return .yellow }
        return .green
    }

    // MARK: - RAM

    private func ramRow(_ ram: RAMMetrics) -> some View {
        MetricRow(
            label: "RAM",
            icon: "memorychip",
            value: ram.usagePercent,
            detail: "\(MetricFormatter.bytes(ram.used))/\(MetricFormatter.bytes(ram.total))"
        )
    }

    // MARK: - GPU

    private func gpuRow(_ gpu: GPUMetrics) -> some View {
        MetricRow(
            label: "GPU",
            icon: "rectangle.3.group",
            value: gpu.utilization,
            detail: MetricFormatter.percent(gpu.utilization)
        )
    }

    // MARK: - Disk

    @ViewBuilder
    private func diskSection(_ disk: DiskMetrics) -> some View {
        Button(action: {
            showDiskBreakdown.toggle()
            if showDiskBreakdown && state.diskBreakdown.isEmpty {
                state.scanDisk()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .frame(width: 16)
                    .foregroundStyle(.secondary)

                Text("Disk")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(.caption, design: .monospaced))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(diskBarColor(disk.usagePercent))
                            .frame(width: geo.size.width * min(max(CGFloat(disk.usagePercent), 0), 1))
                    }
                }
                .frame(height: 8)

                Text("\(MetricFormatter.bytes(disk.used))/\(MetricFormatter.bytes(disk.total))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)

                Image(systemName: showDiskBreakdown ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if showDiskBreakdown {
            diskBreakdownView
                .padding(.leading, 24)
                .padding(.bottom, 4)
        }
    }

    private var diskBreakdownView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if state.isDiskScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Scanning directories...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if state.diskBreakdown.isEmpty {
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.diskBreakdown.prefix(8)) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: folderIcon(entry.name))
                            .font(.caption2)
                            .frame(width: 12)
                            .foregroundStyle(.secondary)
                        Text(entry.name)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text(MetricFormatter.bytes(entry.size))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 16)
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
        default: return "folder"
        }
    }

    private func diskBarColor(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }

    // MARK: - Network

    private func networkSection(_ net: NetworkMetrics) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "network")
                .frame(width: 16)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text(MetricFormatter.speed(net.bytesPerSecUp))
                    .font(.system(.caption, design: .monospaced))
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(MetricFormatter.speed(net.bytesPerSecDown))
                    .font(.system(.caption, design: .monospaced))
            }

            Spacer()
        }
        .frame(height: 20)
        .padding(.vertical, 2)
    }

    // MARK: - Battery

    @ViewBuilder
    private func batterySection(_ battery: BatteryMetrics) -> some View {
        if battery.hasBattery {
            HStack(spacing: 8) {
                Image(systemName: batteryIcon(battery))
                    .frame(width: 16)
                    .foregroundStyle(batteryColor(battery.level))

                Text("\(battery.level)%")
                    .font(.system(.caption, design: .monospaced))

                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("Charging")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if battery.isPluggedIn {
                    Image(systemName: "powerplug.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Plugged In")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(height: 20)
            .padding(.vertical, 2)
        }
    }

    private func batteryIcon(_ battery: BatteryMetrics) -> String {
        if battery.isCharging {
            return "battery.100percent.bolt"
        }
        switch battery.level {
        case 75...100: return "battery.100percent"
        case 50..<75: return "battery.75percent"
        case 25..<50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        if level <= 15 { return .red }
        if level <= 30 { return .orange }
        return .green
    }

    // MARK: - Actions

    private var floatingToggle: some View {
        Button(action: {
            state.toggleFloating()
            dismiss()
        }) {
            HStack {
                Image(systemName: state.isFloatingVisible
                      ? "rectangle.on.rectangle.slash"
                      : "rectangle.on.rectangle")
                Text(state.isFloatingVisible
                     ? "Hide Floating Panel"
                     : "Show Floating Panel")
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quitButton: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack {
                Image(systemName: "power")
                Text("Quit SysBar")
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
