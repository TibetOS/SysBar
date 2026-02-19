# SysBar v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite SysBar from scratch with flat-module architecture, sidebar dashboard, colored health dot, and historical charts.

**Architecture:** Flat modules — Core (data + collection + settings), Services (alerts, disk, updates), Views (menu bar, dashboard sections, shared components). Single MetricStore as source of truth. No GPU metrics.

**Tech Stack:** Swift 6, SwiftUI, macOS 15+, Mach/IOKit/POSIX syscalls, XcodeGen, no third-party deps.

**Design doc:** `docs/plans/2026-02-19-sysbar-redesign.md`

---

### Task 1: Clean slate — remove all old source files

**Files:**
- Delete: `SysBar/SysBarApp.swift`
- Delete: `SysBar/Models/` (entire directory)
- Delete: `SysBar/Views/` (entire directory)
- Delete: `SysBar/Services/` (entire directory)
- Delete: `SysBar/Utilities/` (entire directory)

**Step 1: Remove all old Swift source files**

```bash
rm -rf SysBar/Models SysBar/Views SysBar/Services SysBar/Utilities SysBar/SysBarApp.swift
```

**Step 2: Create the new directory structure**

```bash
mkdir -p SysBar/App SysBar/Core SysBar/Services \
  SysBar/Views/MenuBar SysBar/Views/Dashboard \
  SysBar/Views/Settings SysBar/Views/Shared SysBar/Utilities
```

**Step 3: Commit**

```bash
git add -A && git commit -m "chore: remove all old source files for v2 rewrite"
```

---

### Task 2: Core — MetricTypes

**Files:**
- Create: `SysBar/Core/MetricTypes.swift`

**Step 1: Write MetricTypes.swift**

All pure `Sendable` data structs. No GPU.

```swift
import Foundation

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0.0–1.0
    let perCore: [Double]           // per-core 0.0–1.0
    let coreCount: Int
}

struct RAMMetrics: Sendable {
    let used: UInt64
    let total: UInt64
    let active: UInt64
    let wired: UInt64
    let compressed: UInt64
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct DiskMetrics: Sendable {
    let used: UInt64
    let total: UInt64
    var usagePercent: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct NetworkMetrics: Sendable {
    let upSpeed: UInt64             // bytes/sec
    let downSpeed: UInt64           // bytes/sec
    let totalSent: UInt64           // bytes since boot
    let totalReceived: UInt64       // bytes since boot
}

struct BatteryMetrics: Sendable {
    let level: Int                  // 0–100
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool
    let cycleCount: Int
    let health: Int                 // 0–100
    let temperature: Double         // celsius
}

struct SystemInfo: Sendable {
    let chipName: String
    let macOSVersion: String
    let hostname: String
    let memorySize: String
}

struct SystemSnapshot: Sendable {
    let cpu: CPUMetrics
    let ram: RAMMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics
    let info: SystemInfo
    let timestamp: Date
}
```

**Step 2: Build to verify compilation**

```bash
xcodegen generate && xcodebuild -scheme SysBar build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

This will fail because SysBarApp.swift is missing — that's expected. Just verify MetricTypes.swift has no syntax errors in the compiler output.

**Step 3: Commit**

```bash
git add SysBar/Core/MetricTypes.swift && git commit -m "feat: add metric data types for v2"
```

---

### Task 3: Core — RingBuffer

**Files:**
- Create: `SysBar/Core/RingBuffer.swift`

**Step 1: Write RingBuffer.swift**

Generic fixed-size circular buffer conforming to `RandomAccessCollection` for efficient append + iteration. O(1) append, no Array.removeFirst() overhead.

```swift
import Foundation

struct RingBuffer<Element>: RandomAccessCollection, Sendable where Element: Sendable {
    private var storage: [Element]
    private var head: Int = 0
    private var count_: Int = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count_ }
    var count: Int { count_ }
    var isEmpty: Bool { count_ == 0 }

    subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count_)
        let realIndex = (head + index) % storage.count
        return storage[realIndex]
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
            // count_ stays at capacity
            return
        }
        count_ = storage.count
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
        count_ = 0
    }

    var last: Element? {
        guard !isEmpty else { return nil }
        let idx = storage.count < capacity
            ? storage.count - 1
            : (head + count_ - 1) % capacity
        return storage[idx]
    }

    func toArray() -> [Element] {
        Array(self)
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Core/RingBuffer.swift && git commit -m "feat: add RingBuffer generic collection"
```

---

### Task 4: Core — Settings

**Files:**
- Create: `SysBar/Core/Settings.swift`

**Step 1: Write Settings.swift**

Uses `@AppStorage` for reactive SwiftUI bindings. No manual UserDefaults wrappers.

```swift
import SwiftUI

@Observable
@MainActor
final class Settings {
    @ObservationIgnored @AppStorage("refreshInterval") var refreshInterval: Double = 2.0
    @ObservationIgnored @AppStorage("alertsEnabled") var alertsEnabled: Bool = false
    @ObservationIgnored @AppStorage("cpuThreshold") var cpuThreshold: Double = 0.90
    @ObservationIgnored @AppStorage("ramThreshold") var ramThreshold: Double = 0.90
    @ObservationIgnored @AppStorage("historyMinutes") var historyMinutes: Int = 5
}
```

Note: `@ObservationIgnored` is needed because `@AppStorage` already triggers SwiftUI updates — doubling up with `@Observable` tracking causes issues.

**Step 2: Commit**

```bash
git add SysBar/Core/Settings.swift && git commit -m "feat: add AppStorage-based Settings"
```

---

### Task 5: Core — MetricCollector

**Files:**
- Create: `SysBar/Core/MetricCollector.swift`

**Step 1: Write MetricCollector.swift**

Port all syscall logic from the old `SystemMonitor.swift`. Same Mach/IOKit/POSIX approach, no GPU.

The actor contains:
- Static cached system info (chip name, macOS version, hostname, memory size)
- Delta state for CPU ticks and network bytes
- Methods: `collectCPU()`, `collectRAM()`, `collectDisk()`, `collectNetwork()`, `collectBattery()`, `collectSystemInfo()`, `collectSnapshot()`

**Port these methods verbatim from the old code** (`SysBar/Services/SystemMonitor.swift` — already deleted but available in git history or the design context). Key changes:
- Rename actor from `SystemMonitor` to `MetricCollector`
- Remove `collectGPU()` entirely
- Rename `NetworkMetrics` fields: `bytesPerSecUp` → `upSpeed`, `bytesPerSecDown` → `downSpeed`
- Rename `RAMMetrics` fields: `appMemory` → `active`
- Rename `CPUMetrics` field: `perCoreUsage` → `perCore`
- Remove GPU from `collectSnapshot()` and `SystemSnapshot`

File should be ~300 lines (the one exception to the 150-line guideline — syscall code is dense and splitting it further would reduce readability).

**Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme SysBar build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD'
```

Still expected to fail (no @main entry point yet), but verify no errors in MetricCollector.swift.

**Step 3: Commit**

```bash
git add SysBar/Core/MetricCollector.swift && git commit -m "feat: add MetricCollector actor with syscall logic"
```

---

### Task 6: Core — MetricStore

**Files:**
- Create: `SysBar/Core/MetricStore.swift`

**Step 1: Write MetricStore.swift**

Single source of truth. Owns the polling loop and history buffers. Does NOT manage windows, alerts, or disk scanning.

```swift
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
            // Warm-up: first snapshot establishes deltas
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
```

**Step 2: Commit**

```bash
git add SysBar/Core/MetricStore.swift && git commit -m "feat: add MetricStore with polling and history"
```

---

### Task 7: Utilities — Formatters

**Files:**
- Create: `SysBar/Utilities/Formatters.swift`

**Step 1: Write Formatters.swift**

Port from old code. Two enums: `MetricFormatter` (bytes, speed, percent) and `MetricColor` (usage color, battery color).

```swift
import SwiftUI

enum MetricColor {
    static func usage(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }

    static func battery(_ level: Int) -> Color {
        if level <= 15 { return .red }
        if level <= 30 { return .orange }
        return .green
    }

    static func health(_ cpu: Double, _ ram: Double) -> Color {
        let worst = max(cpu, ram)
        if worst > 0.85 { return .red }
        if worst > 0.60 { return .yellow }
        return .green
    }
}

enum MetricFormatter {
    static func bytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(value) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    static func speed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec >= 1_073_741_824 {
            return String(format: "%.1f GB/s", Double(bytesPerSec) / 1_073_741_824)
        } else if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", Double(bytesPerSec) / 1024)
        }
        return "\(bytesPerSec) B/s"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
```

Note: Added `MetricColor.health(_:_:)` for the menu bar colored dot.

**Step 2: Commit**

```bash
git add SysBar/Utilities/Formatters.swift && git commit -m "feat: add formatters and color utilities"
```

---

### Task 8: Shared views — UsageBar, SparkLine, MetricCard

**Files:**
- Create: `SysBar/Views/Shared/UsageBar.swift`
- Create: `SysBar/Views/Shared/SparkLine.swift`
- Create: `SysBar/Views/Shared/MetricCard.swift`

**Step 1: Write UsageBar.swift**

Reusable colored progress bar. Replaces old `MetricRow`.

```swift
import SwiftUI

struct UsageBar: View {
    let label: String
    let icon: String
    let value: Double       // 0.0–1.0
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(label)
                .frame(width: 44, alignment: .leading)
                .font(.system(.caption, design: .monospaced))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MetricColor.usage(value))
                        .frame(width: geo.size.width * min(max(CGFloat(value), 0), 1))
                }
            }
            .frame(height: 8)
            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .frame(height: 22)
    }
}
```

**Step 2: Write SparkLine.swift**

Canvas-based inline mini chart. Same approach as old, cleaned up.

```swift
import SwiftUI

struct SparkLine<T: BinaryFloatingPoint>: View {
    let values: [T]
    var color: Color = .green
    var height: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let maxVal = values.max() ?? 1
            let normalizer = maxVal > 0 ? maxVal : 1
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (i, value) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - (CGFloat(value / normalizer) * size.height)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            let lineColor = MetricColor.usage(Double(values.last ?? 0))
            context.stroke(path, with: .color(lineColor), lineWidth: 1.5)

            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(lineColor.opacity(0.15)))
        }
        .frame(height: height)
    }
}
```

Note: Generic over `BinaryFloatingPoint` so it works with `[Double]` directly. For UInt64 network history, callers convert to Double first.

**Step 3: Write MetricCard.swift**

Card container used in the dashboard Overview section.

```swift
import SwiftUI

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
```

**Step 4: Commit**

```bash
git add SysBar/Views/Shared/ && git commit -m "feat: add shared view components"
```

---

### Task 9: Shared views — HistoryChart

**Files:**
- Create: `SysBar/Views/Shared/HistoryChart.swift`

**Step 1: Write HistoryChart.swift**

Larger Canvas-based time-series chart for dashboard detail sections. Shows values over time with axis labels.

```swift
import SwiftUI

struct HistoryChart: View {
    let values: [Double]        // normalized 0.0–1.0
    let label: String
    var height: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                Canvas { context, size in
                    drawGrid(context: context, size: size)
                    drawLine(context: context, size: size)
                }
                .frame(height: height)

                if let last = values.last {
                    Text(MetricFormatter.percent(last))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            }

            HStack {
                Text("older")
                Spacer()
                Text("now")
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.quaternary)
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for i in 1..<4 {
            let y = size.height * CGFloat(i) / 4
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.quaternary), lineWidth: 0.5)
        }
    }

    private func drawLine(context: GraphicsContext, size: CGSize) {
        guard values.count >= 2 else { return }
        let stepX = size.width / CGFloat(values.count - 1)

        var path = Path()
        for (i, value) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = size.height - (CGFloat(value) * size.height)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        let color = MetricColor.usage(values.last ?? 0)
        context.stroke(path, with: .color(color), lineWidth: 2)

        var fill = path
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .color(color.opacity(0.1)))
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/Shared/HistoryChart.swift && git commit -m "feat: add HistoryChart component"
```

---

### Task 10: Services — AlertService

**Files:**
- Create: `SysBar/Services/AlertService.swift`

**Step 1: Write AlertService.swift**

Extracted from old AppState. Watches snapshots, sends notifications with cooldown.

```swift
import Foundation
import UserNotifications

@MainActor
final class AlertService {
    private let settings: Settings
    private var lastCPUAlert: Date = .distantPast
    private var lastRAMAlert: Date = .distantPast
    private let cooldown: TimeInterval = 60

    init(settings: Settings) {
        self.settings = settings
        requestPermission()
    }

    func check(_ snapshot: SystemSnapshot) {
        guard settings.alertsEnabled else { return }
        let now = Date()

        if snapshot.cpu.totalUsage >= settings.cpuThreshold,
           now.timeIntervalSince(lastCPUAlert) > cooldown {
            lastCPUAlert = now
            send(title: "High CPU Usage",
                 body: "CPU at \(MetricFormatter.percent(snapshot.cpu.totalUsage))")
        }

        if snapshot.ram.usagePercent >= settings.ramThreshold,
           now.timeIntervalSince(lastRAMAlert) > cooldown {
            lastRAMAlert = now
            send(title: "High RAM Usage",
                 body: "RAM at \(MetricFormatter.percent(snapshot.ram.usagePercent))")
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Services/AlertService.swift && git commit -m "feat: add AlertService for threshold notifications"
```

---

### Task 11: Services — DiskAnalyzer

**Files:**
- Create: `SysBar/Services/DiskAnalyzer.swift`

**Step 1: Write DiskAnalyzer.swift**

Port from old code. Actor that scans directories and returns breakdown.

Include the `DiskEntry` struct in this file (it's only used here and in DiskSection).

```swift
import Foundation

struct DiskEntry: Sendable, Identifiable {
    let name: String
    let path: String
    let size: UInt64
    var id: String { path }
}

actor DiskAnalyzer {
    func analyze() -> [DiskEntry] {
        // Port the exact logic from old DiskAnalyzer.swift:
        // - Scan ~/Library, /Applications, hidden home dirs
        // - Skip TCC-protected dirs (Desktop, Documents, etc.)
        // - Calculate "System & Other" from statvfs total - scanned
        // - Sort by size descending, filter > 10 MB
        // (full implementation from old code)
    }

    private func directorySize(_ url: URL) -> UInt64 {
        // Port from old code — FileManager enumerator + totalFileAllocatedSize
    }

    private func totalDiskUsed() -> UInt64 {
        // Port from old code — statvfs("/")
    }
}
```

Port the method bodies verbatim from the old `SysBar/Services/DiskAnalyzer.swift`.

**Step 2: Commit**

```bash
git add SysBar/Services/DiskAnalyzer.swift && git commit -m "feat: add DiskAnalyzer service"
```

---

### Task 12: Services — UpdateChecker

**Files:**
- Create: `SysBar/Services/UpdateChecker.swift`

**Step 1: Write UpdateChecker.swift**

Port from old code. Fetches latest GitHub release, compares versions, shows alert.

```swift
// Port verbatim from old SysBar/Services/UpdateChecker.swift
// No changes needed — it's already clean and standalone.
// Keep: @Observable @MainActor final class UpdateChecker
// Keep: currentVersion from Bundle.main
// Keep: fetchLatestRelease(), showAlert(), isNewer()
```

**Step 2: Commit**

```bash
git add SysBar/Services/UpdateChecker.swift && git commit -m "feat: add UpdateChecker service"
```

---

### Task 13: Views — MenuBarLabel

**Files:**
- Create: `SysBar/Views/MenuBar/MenuBarLabel.swift`

**Step 1: Write MenuBarLabel.swift**

Colored circle that changes based on system health.

```swift
import SwiftUI

struct MenuBarLabel: View {
    let store: MetricStore

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 10))
            .foregroundStyle(dotColor)
    }

    private var dotColor: Color {
        guard let snap = store.snapshot else { return .gray }
        return MetricColor.health(snap.cpu.totalUsage, snap.ram.usagePercent)
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/MenuBar/MenuBarLabel.swift && git commit -m "feat: add colored health dot menu bar label"
```

---

### Task 14: Views — MenuBarDropdown

**Files:**
- Create: `SysBar/Views/MenuBar/MenuBarDropdown.swift`

**Step 1: Write MenuBarDropdown.swift**

Compact dropdown with one-line per metric and action buttons.

```swift
import SwiftUI

struct MenuBarDropdown: View {
    let store: MetricStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()

            if let snap = store.snapshot {
                metricsSummary(snap)
            } else {
                loadingRow
            }

            Divider()
            openDashboardButton
            Divider()
            settingsButton
            quitButton
        }
        .padding(12)
        .frame(width: 260)
    }

    private var header: some View {
        HStack {
            Text("SysBar").font(.headline)
            Spacer()
            Text("v\(UpdateChecker.currentVersion)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func metricsSummary(_ snap: SystemSnapshot) -> some View {
        summaryRow("cpu", "CPU", MetricFormatter.percent(snap.cpu.totalUsage))
        summaryRow("memorychip", "RAM",
            "\(MetricFormatter.bytes(snap.ram.used)) / \(MetricFormatter.bytes(snap.ram.total))")
        summaryRow("network", "Net",
            "↑\(MetricFormatter.speed(snap.network.upSpeed))  ↓\(MetricFormatter.speed(snap.network.downSpeed))")
        summaryRow("internaldrive", "Disk",
            "\(MetricFormatter.bytes(snap.disk.used)) / \(MetricFormatter.bytes(snap.disk.total))")
        if snap.battery.hasBattery {
            summaryRow(snap.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                       "Bat", "\(snap.battery.level)%")
        }
    }

    private func summaryRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 14).foregroundStyle(.secondary)
            Text(label).font(.system(.caption, design: .monospaced))
                .frame(width: 32, alignment: .leading)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(height: 20)
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView().controlSize(.small)
            Text("Loading...").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var openDashboardButton: some View {
        Button(action: { openWindow(id: "dashboard"); dismiss() }) {
            Label("Open SysBar", systemImage: "gauge.with.dots.needle.33percent")
                .fontWeight(.medium)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsButton: some View {
        Button(action: { openSettings(); dismiss() }) {
            Label("Settings...", systemImage: "gearshape")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quitButton: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit SysBar", systemImage: "power")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/MenuBar/MenuBarDropdown.swift && git commit -m "feat: add compact menu bar dropdown"
```

---

### Task 15: Views — Dashboard shell

**Files:**
- Create: `SysBar/Views/Dashboard/DashboardView.swift`

**Step 1: Write DashboardView.swift**

NavigationSplitView with sidebar and detail area.

```swift
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
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/DashboardView.swift && git commit -m "feat: add dashboard NavigationSplitView shell"
```

---

### Task 16: Views — OverviewSection

**Files:**
- Create: `SysBar/Views/Dashboard/OverviewSection.swift`

**Step 1: Write OverviewSection.swift**

All metrics at a glance with MetricCards and sparklines.

```swift
import SwiftUI

struct OverviewSection: View {
    let store: MetricStore
    let snapshot: SystemSnapshot

    private var uptime: String {
        let secs = ProcessInfo.processInfo.systemUptime
        let days = Int(secs) / 86400
        let hours = (Int(secs) % 86400) / 3600
        let mins = (Int(secs) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h \(mins)m"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                systemInfoHeader
                metricsGrid
                cpuSparkSection
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }

    private var systemInfoHeader: some View {
        HStack(spacing: 16) {
            infoTag(snapshot.info.chipName)
            infoTag("macOS \(snapshot.info.macOSVersion)")
            infoTag(snapshot.info.memorySize)
            infoTag("Up \(uptime)")
        }
    }

    private func infoTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(icon: "cpu", title: "CPU",
                       value: MetricFormatter.percent(snapshot.cpu.totalUsage),
                       color: MetricColor.usage(snapshot.cpu.totalUsage))
            MetricCard(icon: "memorychip", title: "Memory",
                       value: MetricFormatter.bytes(snapshot.ram.used),
                       color: MetricColor.usage(snapshot.ram.usagePercent))
            MetricCard(icon: "network", title: "Network",
                       value: "↑\(MetricFormatter.speed(snapshot.network.upSpeed))")
            MetricCard(icon: "internaldrive", title: "Disk",
                       value: MetricFormatter.percent(snapshot.disk.usagePercent),
                       color: MetricColor.usage(snapshot.disk.usagePercent))
        }
    }

    private var cpuSparkSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CPU History").font(.caption).foregroundStyle(.secondary)
            SparkLine(values: store.cpuHistory.toArray(), height: 40)
        }
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/OverviewSection.swift && git commit -m "feat: add Overview dashboard section"
```

---

### Task 17: Views — CPUSection

**Files:**
- Create: `SysBar/Views/Dashboard/CPUSection.swift`

**Step 1: Write CPUSection.swift**

CPU detail: usage bar, per-core grid, sparkline, history chart.

```swift
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
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/CPUSection.swift && git commit -m "feat: add CPU dashboard section"
```

---

### Task 18: Views — MemorySection

**Files:**
- Create: `SysBar/Views/Dashboard/MemorySection.swift`

**Step 1: Write MemorySection.swift**

RAM usage bar, breakdown (active/wired/compressed), history chart.

```swift
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
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/MemorySection.swift && git commit -m "feat: add Memory dashboard section"
```

---

### Task 19: Views — NetworkSection

**Files:**
- Create: `SysBar/Views/Dashboard/NetworkSection.swift`

**Step 1: Write NetworkSection.swift**

Upload/download speeds, totals since boot, history chart.

For network history chart, normalize UInt64 values to 0.0–1.0 using the max value in the buffer.

```swift
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
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/NetworkSection.swift && git commit -m "feat: add Network dashboard section"
```

---

### Task 20: Views — DiskSection

**Files:**
- Create: `SysBar/Views/Dashboard/DiskSection.swift`

**Step 1: Write DiskSection.swift**

Disk usage bar + on-demand breakdown scanner.

```swift
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
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/DiskSection.swift && git commit -m "feat: add Disk dashboard section"
```

---

### Task 21: Views — BatterySection

**Files:**
- Create: `SysBar/Views/Dashboard/BatterySection.swift`

**Step 1: Write BatterySection.swift**

Battery level, health, cycle count, temperature. Shows "No Battery" for desktops.

```swift
import SwiftUI

struct BatterySection: View {
    let battery: BatteryMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if battery.hasBattery {
                    batteryContent
                } else {
                    noBatteryView
                }
            }
            .padding(20)
        }
        .navigationTitle("Battery")
    }

    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                    .font(.largeTitle)
                    .foregroundStyle(MetricColor.battery(battery.level))
                VStack(alignment: .leading) {
                    Text("\(battery.level)%")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(statusText)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(icon: "heart", title: "Health", value: "\(battery.health)%",
                           color: MetricColor.battery(battery.health))
                MetricCard(icon: "arrow.triangle.2.circlepath", title: "Cycles",
                           value: "\(battery.cycleCount)")
                if battery.temperature > 0 {
                    MetricCard(icon: "thermometer", title: "Temp",
                               value: String(format: "%.1f\u{00B0}C", battery.temperature))
                }
            }
        }
    }

    private var statusText: String {
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged In" }
        return "On Battery"
    }

    private var noBatteryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Battery Detected")
                .font(.headline).foregroundStyle(.secondary)
            Text("This Mac doesn't have a battery.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/Dashboard/BatterySection.swift && git commit -m "feat: add Battery dashboard section"
```

---

### Task 22: Views — SettingsView

**Files:**
- Create: `SysBar/Views/Settings/SettingsView.swift`

**Step 1: Write SettingsView.swift**

Uses `@AppStorage` bindings directly. Includes launch-at-login, refresh rate, alerts, thresholds.

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("alertsEnabled") private var alertsEnabled: Bool = false
    @AppStorage("cpuThreshold") private var cpuThreshold: Double = 0.90
    @AppStorage("ramThreshold") private var ramThreshold: Double = 0.90
    @AppStorage("historyMinutes") private var historyMinutes: Int = 5
    @State private var updateChecker = UpdateChecker()

    var body: some View {
        Form {
            generalSection
            alertsSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Picker("Refresh Rate", selection: $refreshInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }

            Picker("History Duration", selection: $historyMinutes) {
                Text("1 minute").tag(1)
                Text("5 minutes").tag(5)
                Text("10 minutes").tag(10)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }
        }
    }

    private var alertsSection: some View {
        Section("Alerts") {
            Toggle("Enable Threshold Alerts", isOn: $alertsEnabled)
            if alertsEnabled {
                HStack {
                    Text("CPU Alert")
                    Spacer()
                    Text("\(Int(cpuThreshold * 100))%")
                        .foregroundStyle(.secondary).frame(width: 40)
                    Slider(value: $cpuThreshold, in: 0.5...1.0, step: 0.05)
                        .frame(width: 150)
                }
                HStack {
                    Text("RAM Alert")
                    Spacer()
                    Text("\(Int(ramThreshold * 100))%")
                        .foregroundStyle(.secondary).frame(width: 40)
                    Slider(value: $ramThreshold, in: 0.5...1.0, step: 0.05)
                        .frame(width: 150)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "v\(UpdateChecker.currentVersion)")
            LabeledContent("GitHub") {
                Link("TibetOS/SysBar",
                     destination: URL(string: "https://github.com/TibetOS/SysBar")!)
            }
            Button(action: { updateChecker.checkForUpdates() }) {
                HStack(spacing: 6) {
                    if updateChecker.isChecking { ProgressView().controlSize(.small) }
                    Text(updateChecker.isChecking ? "Checking..." : "Check for Updates...")
                }
            }
            .disabled(updateChecker.isChecking)
        }
    }
}
```

**Step 2: Commit**

```bash
git add SysBar/Views/Settings/SettingsView.swift && git commit -m "feat: add SettingsView with AppStorage"
```

---

### Task 23: App — SysBarApp entry point

**Files:**
- Create: `SysBar/App/SysBarApp.swift`

**Step 1: Write SysBarApp.swift**

Wires everything together: MetricStore, Settings, AlertService, MenuBarExtra, Window, Settings scene.

```swift
import SwiftUI

@main
struct SysBarApp: App {
    @State private var settings = Settings()
    @State private var store: MetricStore
    @State private var alertService: AlertService

    init() {
        let s = Settings()
        let m = MetricStore(settings: s)
        _settings = State(initialValue: s)
        _store = State(initialValue: m)
        _alertService = State(initialValue: AlertService(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarDropdown(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("SysBar", id: "dashboard") {
            DashboardView(store: store, settings: settings)
                .onAppear { store.startPolling() }
        }
        .defaultSize(width: 700, height: 500)
        .defaultPosition(.center)

        SwiftUI.Settings {
            SettingsView()
        }
    }
}
```

Note: `store.startPolling()` is called on dashboard window appear, but the menu bar needs data too. Move polling start to `init` or use `.task` on the MenuBarExtra. Revisit during implementation — the simplest approach is to call `store.startPolling()` in `init()`.

**Step 2: Regenerate Xcode project and build**

```bash
xcodegen generate && xcodebuild -scheme SysBar -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|warning:|BUILD'
```

Expected: **BUILD SUCCEEDED**

**Step 3: Commit**

```bash
git add SysBar/App/SysBarApp.swift && git commit -m "feat: add SysBarApp entry point wiring all components"
```

---

### Task 24: Update project config and CLAUDE.md

**Files:**
- Modify: `project.yml` — update MARKETING_VERSION to 0.8.0
- Modify: `CLAUDE.md` — update project structure
- Modify: `VERSION` — update to 0.8.0

**Step 1: Bump version to 0.8.0**

Update `MARKETING_VERSION` in `project.yml` from `0.7.0` to `0.8.0`.
Update `VERSION` file to `0.8.0`.

**Step 2: Update CLAUDE.md**

Replace project structure section to reflect new flat-module layout.

**Step 3: Regenerate project, final build**

```bash
xcodegen generate && xcodebuild -scheme SysBar -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD'
```

**Step 4: Commit**

```bash
git add -A && git commit -m "chore: bump version to 0.8.0, update project config"
```

---

### Task 25: Smoke test — run the app

**Step 1: Build and launch**

```bash
xcodebuild -scheme SysBar -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep 'BUILD'
```

Then open the .app from DerivedData or run via Xcode to verify:
- Colored dot appears in menu bar
- Clicking dot opens dropdown with live metrics
- "Open SysBar" button opens dashboard window
- Sidebar navigation works (Overview, CPU, Memory, Network, Disk, Battery)
- Sparklines and history charts render
- Settings window opens
- Quit works

**Step 2: Fix any issues found during smoke test**

**Step 3: Final commit if fixes were needed**
