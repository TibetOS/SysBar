import SwiftUI

struct OverviewSection: View {
    let store: MetricStore
    let snapshot: SystemSnapshot

    private var uptime: String {
        let secs = ProcessInfo.processInfo.systemUptime
        let days = Int(secs) / 86400
        let hours = (Int(secs) % 86400) / 3600
        let mins = (Int(secs) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h \(mins)m"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                systemInfoHeader
                metricsGrid
                cpuSparkSection
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }

    private var systemInfoHeader: some View {
        HStack(spacing: 16) {
            infoTag(snapshot.info.chipName)
            infoTag("macOS \(snapshot.info.macOSVersion)")
            infoTag(snapshot.info.memorySize)
            infoTag("Up \(uptime)")
        }
    }

    private func infoTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(icon: "cpu", title: "CPU",
                       value: MetricFormatter.percent(snapshot.cpu.totalUsage),
                       color: MetricColor.usage(snapshot.cpu.totalUsage))
            MetricCard(icon: "memorychip", title: "Memory",
                       value: MetricFormatter.bytes(snapshot.ram.used),
                       color: MetricColor.usage(snapshot.ram.usagePercent))
            MetricCard(icon: "network", title: "Network",
                       value: "↑\(MetricFormatter.speed(snapshot.network.upSpeed))")
            MetricCard(icon: "internaldrive", title: "Disk",
                       value: MetricFormatter.percent(snapshot.disk.usagePercent),
                       color: MetricColor.usage(snapshot.disk.usagePercent))
        }
    }

    private var cpuSparkSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CPU History").font(.caption).foregroundStyle(.secondary)
            SparkLine(values: store.cpuHistory.toArray(), height: 40)
        }
    }
}
