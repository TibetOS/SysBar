import SwiftUI

@Observable
@MainActor
final class MetricStore {
    var snapshot: SystemSnapshot?
    var cpuHistory = RingBuffer<Double>(capacity: 300)
    var ramHistory = RingBuffer<Double>(capacity: 300)
    var networkUpHistory = RingBuffer<UInt64>(capacity: 300)
    var networkDownHistory = RingBuffer<UInt64>(capacity: 300)

    private let collector = MetricCollector()
    private let settings: Settings
    private var pollTask: Task<Void, Never>?

    init(settings: Settings) {
        self.settings = settings
    }

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task {
            _ = await collector.collectSnapshot()
            try? await Task.sleep(for: .seconds(1))

            while !Task.isCancelled {
                let snap = await collector.collectSnapshot()
                self.snapshot = snap
                self.cpuHistory.append(snap.cpu.totalUsage)
                self.ramHistory.append(snap.ram.usagePercent)
                self.networkUpHistory.append(snap.network.upSpeed)
                self.networkDownHistory.append(snap.network.downSpeed)
                try? await Task.sleep(for: .seconds(settings.refreshInterval))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
