import SwiftUI

@Observable
@MainActor
final class AppState {
    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    private let monitor = SystemMonitor()
    private var refreshTask: Task<Void, Never>?
    private let maxHistorySize = 20

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            // Prime the deltas with an initial sample
            _ = await monitor.collectSnapshot()
            try? await Task.sleep(for: .seconds(1))

            while !Task.isCancelled {
                let snap = await monitor.collectSnapshot()
                self.snapshot = snap
                self.cpuHistory.append(snap.cpu.totalUsage)
                if self.cpuHistory.count > self.maxHistorySize {
                    self.cpuHistory.removeFirst()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopMonitoring() {
        refreshTask?.cancel()
    }
}
