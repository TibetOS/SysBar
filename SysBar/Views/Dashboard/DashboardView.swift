import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview, cpu, memory, network, disk, battery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Network"
        case .disk: "Disk"
        case .battery: "Battery"
        }
    }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .network: "network"
        case .disk: "internaldrive"
        case .battery: "battery.100percent"
        }
    }
}

struct DashboardView: View {
    let store: MetricStore
    let settings: Settings
    @State private var selection: DashboardSection = .overview

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            if let snap = store.snapshot {
                detailContent(snap)
            } else {
                ProgressView("Collecting metrics...")
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private func detailContent(_ snap: SystemSnapshot) -> some View {
        switch selection {
        case .overview: OverviewSection(store: store, snapshot: snap)
        case .cpu: CPUSection(store: store, cpu: snap.cpu, info: snap.info)
        case .memory: MemorySection(store: store, ram: snap.ram)
        case .network: NetworkSection(store: store, network: snap.network)
        case .disk: DiskSection(disk: snap.disk)
        case .battery: BatterySection(battery: snap.battery)
        }
    }
}
