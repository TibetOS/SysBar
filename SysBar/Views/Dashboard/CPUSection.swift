import SwiftUI

struct CPUSection: View {
    let store: MetricStore
    let cpu: CPUMetrics
    let info: SystemInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UsageBar(label: "CPU", icon: "cpu",
                         value: cpu.totalUsage,
                         detail: MetricFormatter.percent(cpu.totalUsage))

                coreGrid
                HistoryChart(values: store.cpuHistory.toArray(), label: "CPU Usage Over Time")

                HStack(spacing: 12) {
                    Text(info.chipName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(cpu.coreCount) cores")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
        .navigationTitle("CPU")
    }

    private var coreGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(14), spacing: 4),
                            count: min(cpu.coreCount, 10))
        return VStack(alignment: .leading, spacing: 4) {
            Text("Per-Core").font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { idx, usage in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MetricColor.usage(usage))
                            .frame(width: 14, height: 14)
                        Text("\(idx)")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .help("Core \(idx): \(MetricFormatter.percent(usage))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
