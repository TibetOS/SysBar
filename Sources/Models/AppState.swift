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
            let x = screen.visibleFrame.maxX - 270
            let y = screen.visibleFrame.maxY - 230
            let frame = NSRect(x: x, y: y, width: 250, height: 200)

            let panel = FloatingPanel(contentRect: frame)
            let hostingView = NSHostingView(rootView: FloatingView(state: self))
            hostingView.frame = panel.contentView?.bounds ?? frame
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
            floatingPanel = panel
        }
        floatingPanel?.makeKeyAndOrderFront(nil)
    }

    private func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }
}
