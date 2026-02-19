import SwiftUI

struct NetworkSection: View {
    let store: MetricStore
    let network: NetworkMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                speedRow
                totals
                uploadChart
                downloadChart
            }
            .padding(20)
        }
        .navigationTitle("Network")
    }

    private var speedRow: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up").foregroundStyle(.blue)
                Text(MetricFormatter.speed(network.upSpeed))
                    .font(.system(.title3, design: .monospaced, weight: .medium))
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.down").foregroundStyle(.green)
                Text(MetricFormatter.speed(network.downSpeed))
                    .font(.system(.title3, design: .monospaced, weight: .medium))
            }
            Spacer()
        }
    }

    private var totals: some View {
        HStack(spacing: 16) {
            Text("Total sent: \(MetricFormatter.bytes(network.totalSent))")
            Text("Total received: \(MetricFormatter.bytes(network.totalReceived))")
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.tertiary)
    }

    private var uploadChart: some View {
        HistoryChart(values: normalized(store.networkUpHistory.toArray()), label: "Upload Speed")
    }

    private var downloadChart: some View {
        HistoryChart(values: normalized(store.networkDownHistory.toArray()), label: "Download Speed")
    }

    private func normalized(_ values: [UInt64]) -> [Double] {
        let maxVal = Double(values.max() ?? 1)
        let divisor = maxVal > 0 ? maxVal : 1
        return values.map { Double($0) / divisor }
    }
}
