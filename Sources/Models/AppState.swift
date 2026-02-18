import SwiftUI
import AppKit

@Observable
@MainActor
final class AppState {
    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    var isFloatingVisible = false
    var isFloatingExpanded = true
    var diskBreakdown: [DiskEntry] = []
    var isDiskScanning = false
    private let monitor = SystemMonitor()
    private let diskAnalyzer = DiskAnalyzer()
    private var refreshTask: Task<Void, Never>?
    private let maxHistorySize = 20
    private var floatingPanel: FloatingPanel?

    private let compactSize = NSSize(width: 250, height: 200)
    private let expandedSize = NSSize(width: 400, height: 580)

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        guard refreshTask == nil else { return }
        refreshTask = Task {
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

    // MARK: - Disk Breakdown

    func scanDisk() {
        guard !isDiskScanning else { return }
        isDiskScanning = true
        Task {
            let entries = await diskAnalyzer.analyze()
            self.diskBreakdown = entries
            self.isDiskScanning = false
        }
    }

    func openDiskBreakdown() {
        scanDisk()
        if !isFloatingVisible {
            isFloatingVisible = true
            isFloatingExpanded = true
            showFloatingPanel()
        } else {
            isFloatingExpanded = true
        }
        resizePanel()
    }

    func toggleExpanded() {
        isFloatingExpanded.toggle()
        if isFloatingExpanded && diskBreakdown.isEmpty {
            scanDisk()
        }
        resizePanel()
    }

    // MARK: - Floating Panel

    func toggleFloating() {
        isFloatingVisible.toggle()
        if isFloatingVisible {
            showFloatingPanel()
            if isFloatingExpanded && diskBreakdown.isEmpty {
                scanDisk()
            }
        } else {
            hideFloatingPanel()
        }
    }

    private func showFloatingPanel() {
        if floatingPanel == nil {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let size = isFloatingExpanded ? expandedSize : compactSize
            let x = screen.visibleFrame.maxX - size.width - 20
            let y = screen.visibleFrame.maxY - size.height - 20
            let frame = NSRect(origin: CGPoint(x: x, y: y), size: size)

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

    private func resizePanel() {
        guard let panel = floatingPanel else { return }
        let newSize = isFloatingExpanded ? expandedSize : compactSize
        var frame = panel.frame
        // Keep top-right corner anchored
        frame.origin.y += frame.height - newSize.height
        frame.size = newSize
        panel.setFrame(frame, display: true, animate: true)
    }
}
