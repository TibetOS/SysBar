import SwiftUI

struct DiskSection: View {
    let disk: DiskMetrics
    @State private var breakdown: [DiskEntry] = []
    @State private var isScanning = false
    private let analyzer = DiskAnalyzer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UsageBar(label: "Disk", icon: "internaldrive",
                         value: disk.usagePercent,
                         detail: "\(MetricFormatter.bytes(disk.used)) / \(MetricFormatter.bytes(disk.total))")

                scanButton
                if !breakdown.isEmpty { breakdownList }
            }
            .padding(20)
        }
        .navigationTitle("Disk")
    }

    private var scanButton: some View {
        Button(action: scan) {
            HStack(spacing: 6) {
                if isScanning {
                    ProgressView().controlSize(.small)
                }
                Text(isScanning ? "Scanning..." : "Scan Disk Breakdown")
            }
        }
        .disabled(isScanning)
    }

    private var breakdownList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breakdown").font(.caption).foregroundStyle(.secondary)
            ForEach(breakdown.prefix(10)) { entry in
                HStack {
                    Image(systemName: folderIcon(entry.name))
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                    Text(entry.name)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(MetricFormatter.bytes(entry.size))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 22)
            }
        }
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        Task {
            breakdown = await analyzer.analyze()
            isScanning = false
        }
    }

    private func folderIcon(_ name: String) -> String {
        switch name {
        case "Applications": "app.badge"
        case "Library": "books.vertical"
        case "System & Other": "gearshape"
        case "Trash": "trash"
        default: "folder"
        }
    }
}
