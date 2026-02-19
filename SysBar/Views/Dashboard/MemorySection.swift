import SwiftUI

struct MemorySection: View {
    let store: MetricStore
    let ram: RAMMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UsageBar(label: "RAM", icon: "memorychip",
                         value: ram.usagePercent,
                         detail: "\(MetricFormatter.bytes(ram.used)) / \(MetricFormatter.bytes(ram.total))")

                breakdown
                HistoryChart(values: store.ramHistory.toArray(), label: "Memory Usage Over Time")
            }
            .padding(20)
        }
        .navigationTitle("Memory")
    }

    private var breakdown: some View {
        HStack(spacing: 16) {
            breakdownItem("Active", value: ram.active, color: .blue)
            breakdownItem("Wired", value: ram.wired, color: .orange)
            breakdownItem("Compressed", value: ram.compressed, color: .purple)
        }
    }

    private func breakdownItem(_ label: String, value: UInt64, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label): \(MetricFormatter.bytes(value))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
