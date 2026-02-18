import SwiftUI
import AppKit

@Observable
@MainActor
final class AppState {
    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    var isFloatingVisible = false
    private let monitor = SystemMonitor()
    private var refreshTask: Task<Void, Never>?
    private let maxHistorySize = 20
    private var floatingPanel: FloatingPanel?

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

    // MARK: - Floating Panel

    func toggleFloating() {
        isFloatingVisible.toggle()
        if isFloatingVisible {
            showFloatingPanel()
        } else {
            hideFloatingPanel()
        }
    }

    private func showFloatingPanel() {
        if floatingPanel == nil {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let x = screen.visibleFrame.maxX - 220
            let y = screen.visibleFrame.maxY - 250
            let frame = NSRect(x: x, y: y, width: 200, height: 200)

            let panel = FloatingPanel(contentRect: frame)
            panel.contentView = NSHostingView(rootView: FloatingView(state: self))
            floatingPanel = panel
        }
        floatingPanel?.orderFront(nil)
    }

    private func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }
}
