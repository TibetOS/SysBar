import SwiftUI

struct MenuBarDropdown: View {
    let store: MetricStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()

            if let snap = store.snapshot {
                metricsSummary(snap)
            } else {
                loadingRow
            }

            Divider()
            openDashboardButton
            Divider()
            settingsButton
            quitButton
        }
        .padding(12)
        .frame(width: 260)
    }

    private var header: some View {
        HStack {
            Text("SysBar").font(.headline)
            Spacer()
            Text("v\(UpdateChecker.currentVersion)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func metricsSummary(_ snap: SystemSnapshot) -> some View {
        summaryRow("cpu", "CPU", MetricFormatter.percent(snap.cpu.totalUsage))
        summaryRow("memorychip", "RAM",
            "\(MetricFormatter.bytes(snap.ram.used)) / \(MetricFormatter.bytes(snap.ram.total))")
        summaryRow("network", "Net",
            "↑\(MetricFormatter.speed(snap.network.upSpeed))  ↓\(MetricFormatter.speed(snap.network.downSpeed))")
        summaryRow("internaldrive", "Disk",
            "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")
        if snap.battery.hasBattery {
            summaryRow(snap.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                       "Bat", "\(snap.battery.level)%")
        }
    }

    private func summaryRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 14).foregroundStyle(.secondary)
            Text(label).font(.system(.caption, design: .monospaced))
                .frame(width: 32, alignment: .leading)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(height: 20)
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView().controlSize(.small)
            Text("Loading...").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var openDashboardButton: some View {
        Button(action: { openWindow(id: "dashboard"); dismiss() }) {
            Label("Open SysBar", systemImage: "gauge.with.dots.needle.33percent")
                .fontWeight(.medium)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsButton: some View {
        Button(action: { openSettings(); dismiss() }) {
            Label("Settings...", systemImage: "gearshape")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quitButton: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit SysBar", systemImage: "power")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
