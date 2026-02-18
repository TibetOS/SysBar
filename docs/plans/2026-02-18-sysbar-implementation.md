# SysBar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that displays real-time CPU, RAM, GPU, disk, network, and battery metrics with a spark-line icon and dropdown panel.

**Architecture:** Pure SwiftUI app using `MenuBarExtra` with `.window` style. A single `SystemMonitor` actor collects all metrics via direct syscalls (Mach APIs, IOKit, POSIX) on a 2-second timer. Views observe an `@Observable` AppState that the monitor updates.

**Tech Stack:** Swift 6, SwiftUI, SPM, macOS 15+, Mach/IOKit/POSIX system APIs, no third-party deps.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/SysBarApp.swift`
- Create: `.gitignore`
- Create: `LICENSE`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SysBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "SysBar",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
```

**Step 2: Create minimal SysBarApp.swift**

```swift
import SwiftUI

@main
struct SysBarApp: App {
    var body: some Scene {
        MenuBarExtra("SysBar", systemImage: "chart.bar.fill") {
            Text("SysBar - Loading...")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
```

**Step 3: Create .gitignore**

```
.DS_Store
.build/
.swiftpm/
*.xcodeproj
xcuserdata/
DerivedData/
```

**Step 4: Create LICENSE (MIT)**

Standard MIT license with copyright 2026.

**Step 5: Build and verify**

Run: `cd /Users/galtibet/Apps/SysBar && swift build`
Expected: Build succeeds, binary at `.build/debug/SysBar`

**Step 6: Commit**

```bash
git add Package.swift Sources/SysBarApp.swift .gitignore LICENSE
git commit -m "feat: scaffold SysBar menu bar app with SPM"
```

---

### Task 2: Data Models

**Files:**
- Create: `Sources/Models/SystemMetrics.swift`

**Step 1: Define all metric data structures**

```swift
import Foundation

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0.0 - 1.0
    let perCoreUsage: [Double]      // per-core 0.0 - 1.0
    let coreCount: Int
}

struct RAMMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    var usagePercent: Double { Double(used) / Double(total) }
}

struct GPUMetrics: Sendable {
    let utilization: Double         // 0.0 - 1.0
    let vramUsed: UInt64?           // bytes, nil if unavailable
    let vramTotal: UInt64?          // bytes, nil if unavailable
}

struct DiskMetrics: Sendable {
    let used: UInt64                // bytes
    let total: UInt64               // bytes
    var usagePercent: Double { Double(used) / Double(total) }
}

struct NetworkMetrics: Sendable {
    let bytesPerSecUp: UInt64
    let bytesPerSecDown: UInt64
}

struct BatteryMetrics: Sendable {
    let level: Int                  // 0-100
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool
}

struct SystemSnapshot: Sendable {
    let cpu: CPUMetrics
    let ram: RAMMetrics
    let gpu: GPUMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics
    let timestamp: Date
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Models/SystemMetrics.swift
git commit -m "feat: add system metrics data models"
```

---

### Task 3: Formatters

**Files:**
- Create: `Sources/Utilities/Formatters.swift`

**Step 1: Implement byte and speed formatters**

```swift
import Foundation

enum MetricFormatter {
    static func bytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
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

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Utilities/Formatters.swift
git commit -m "feat: add metric formatters for bytes, speed, percent"
```

---

### Task 4: System Monitor — CPU & RAM

**Files:**
- Create: `Sources/Services/SystemMonitor.swift`

**Step 1: Implement CPU collection using Mach host API**

Uses `host_processor_info()` to get per-CPU tick counts, calculates delta between samples to derive usage percentages. This is the same approach used by Activity Monitor.

**Step 2: Implement RAM collection using host_statistics64**

Uses `host_statistics64()` with `HOST_VM_INFO64` to get page counts, multiplies by `vm_page_size` to get byte values. "Used" = active + wired (matches Activity Monitor's definition).

**Step 3: Create the actor skeleton with CPU + RAM**

```swift
import Foundation
import Darwin

actor SystemMonitor {
    private var previousCPUInfo: [processor_cpu_load_info]?

    func collectCPU() -> CPUMetrics {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return CPUMetrics(totalUsage: 0, perCoreUsage: [], coreCount: 0)
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let coreCount = Int(numCPUs)
        var currentInfo: [processor_cpu_load_info] = []

        for i in 0..<coreCount {
            let offset = Int32(i) * CPU_STATE_MAX
            var info = processor_cpu_load_info()
            info.cpu_ticks.0 = UInt32(cpuInfo[Int(offset + CPU_STATE_USER)])
            info.cpu_ticks.1 = UInt32(cpuInfo[Int(offset + CPU_STATE_SYSTEM)])
            info.cpu_ticks.2 = UInt32(cpuInfo[Int(offset + CPU_STATE_IDLE)])
            info.cpu_ticks.3 = UInt32(cpuInfo[Int(offset + CPU_STATE_NICE)])
            currentInfo.append(info)
        }

        var perCore: [Double] = []
        if let prev = previousCPUInfo, prev.count == coreCount {
            for i in 0..<coreCount {
                let userDelta = Double(currentInfo[i].cpu_ticks.0 - prev[i].cpu_ticks.0)
                let sysDelta = Double(currentInfo[i].cpu_ticks.1 - prev[i].cpu_ticks.1)
                let idleDelta = Double(currentInfo[i].cpu_ticks.2 - prev[i].cpu_ticks.2)
                let niceDelta = Double(currentInfo[i].cpu_ticks.3 - prev[i].cpu_ticks.3)
                let total = userDelta + sysDelta + idleDelta + niceDelta
                let usage = total > 0 ? (userDelta + sysDelta + niceDelta) / total : 0
                perCore.append(min(max(usage, 0), 1))
            }
        } else {
            perCore = Array(repeating: 0, count: coreCount)
        }

        previousCPUInfo = currentInfo
        let totalUsage = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
        return CPUMetrics(totalUsage: totalUsage, perCoreUsage: perCore, coreCount: coreCount)
    }

    func collectRAM() -> RAMMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMMetrics(used: 0, total: 0)
        }

        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let used = active + wired

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        return RAMMetrics(used: used, total: totalBytes)
    }
}
```

**Step 4: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 5: Commit**

```bash
git add Sources/Services/SystemMonitor.swift
git commit -m "feat: add CPU and RAM collection via Mach APIs"
```

---

### Task 5: System Monitor — GPU, Disk, Network, Battery

**Files:**
- Modify: `Sources/Services/SystemMonitor.swift`

**Step 1: Add GPU collection via IOKit**

Uses `IOServiceMatching("AGXAccelerator")` to find Apple GPU, reads `"PerformanceStatistics"` dictionary for utilization. Falls back gracefully if not available.

**Step 2: Add Disk collection via statvfs**

Uses POSIX `statvfs()` on `"/"` to get total and available blocks, calculates used space.

**Step 3: Add Network collection via getifaddrs**

Uses `getifaddrs()` to iterate network interfaces, sums `ifi_ibytes` and `ifi_obytes` from `if_data`, excludes loopback `lo0`. Calculates delta between samples for speed.

**Step 4: Add Battery collection via IOKit**

Uses `IOServiceMatching("AppleSmartBattery")` to read `CurrentCapacity`, `MaxCapacity`, `IsCharging`, `ExternalConnected`.

**Step 5: Add the full snapshot method and refresh loop**

```swift
// Add to SystemMonitor actor:
private var previousNetworkBytes: (sent: UInt64, received: UInt64)?
private var previousNetworkTime: Date?

func collectSnapshot() -> SystemSnapshot {
    SystemSnapshot(
        cpu: collectCPU(),
        ram: collectRAM(),
        gpu: collectGPU(),
        disk: collectDisk(),
        network: collectNetwork(),
        battery: collectBattery(),
        timestamp: Date()
    )
}
```

**Step 6: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 7: Commit**

```bash
git add Sources/Services/SystemMonitor.swift
git commit -m "feat: add GPU, disk, network, battery collection"
```

---

### Task 6: App State (Observable)

**Files:**
- Create: `Sources/Models/AppState.swift`

**Step 1: Create the observable app state with refresh loop**

```swift
import SwiftUI

@Observable
@MainActor
final class AppState {
    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    private let monitor = SystemMonitor()
    private var refreshTask: Task<Void, Never>?
    private let maxHistorySize = 20

    func startMonitoring() {
        refreshTask = Task {
            // Initial sample to prime deltas
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
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Models/AppState.swift
git commit -m "feat: add observable AppState with refresh loop"
```

---

### Task 7: SparkLine View

**Files:**
- Create: `Sources/Views/SparkLine.swift`

**Step 1: Implement the Canvas-based spark-line**

Renders a mini line chart of CPU history as a SwiftUI `Canvas`. Uses normalized values (0-1) to draw smooth lines. Colors based on current CPU level.

```swift
import SwiftUI

struct SparkLine: View {
    let values: [Double]
    let width: CGFloat = 50
    let height: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let stepX = size.width / CGFloat(values.count - 1)
            var path = Path()

            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(value) * size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let color = sparkColor(for: values.last ?? 0)
            context.stroke(path, with: .color(color), lineWidth: 1.5)

            // Fill under the line
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(color.opacity(0.2)))
        }
        .frame(width: width, height: height)
    }

    private func sparkColor(for value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .yellow }
        return .green
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Views/SparkLine.swift
git commit -m "feat: add Canvas-based SparkLine view"
```

---

### Task 8: MetricRow View

**Files:**
- Create: `Sources/Views/MetricRow.swift`

**Step 1: Create reusable metric row with progress bar**

```swift
import SwiftUI

struct MetricRow: View {
    let label: String
    let icon: String
    let value: Double          // 0.0 - 1.0
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(label)
                .frame(width: 40, alignment: .leading)
                .font(.system(.caption, design: .monospaced))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: value))
                        .frame(width: geo.size.width * min(max(CGFloat(value), 0), 1))
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func barColor(for value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .orange }
        return .green
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Views/MetricRow.swift
git commit -m "feat: add reusable MetricRow view component"
```

---

### Task 9: Main Panel View

**Files:**
- Create: `Sources/Views/SysBarPanel.swift`

**Step 1: Build the full dropdown panel composing MetricRow and sections**

Displays all six metrics (CPU, RAM, GPU, Disk, Network, Battery) using `MetricRow` components. Network and battery get custom layouts since they don't fit the progress bar pattern. Per-core CPU displayed as a grid of mini bars.

**Step 2: Build to verify**

Run: `swift build`
Expected: Compiles cleanly.

**Step 3: Commit**

```bash
git add Sources/Views/SysBarPanel.swift
git commit -m "feat: add main SysBarPanel dropdown view"
```

---

### Task 10: Wire Everything in SysBarApp

**Files:**
- Modify: `Sources/SysBarApp.swift`

**Step 1: Connect AppState, SparkLine label, and SysBarPanel**

Update the app entry point to:
- Create `AppState` as `@State`
- Start monitoring on appear
- Use `SparkLine` in the menu bar label
- Use `SysBarPanel` as the dropdown content
- Set `.accessory` activation policy (no Dock icon)

**Step 2: Build and run**

Run: `swift build && swift run SysBar`
Expected: App appears in menu bar with spark-line, clicking shows metrics panel.

**Step 3: Commit**

```bash
git add Sources/SysBarApp.swift
git commit -m "feat: wire app state, spark-line, and panel together"
```

---

### Task 11: README and GitHub Repo

**Files:**
- Create: `README.md`
- Create: `Sources/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Write README with screenshots placeholder, build instructions, feature list**

**Step 2: Create minimal Assets.xcassets structure**

**Step 3: Create GitHub repo and push**

```bash
gh repo create SysBar --public --description "Lightweight macOS menu bar app for real-time system resource monitoring" --source .
git push -u origin main
```

**Step 4: Create initial release v0.1.0**

```bash
gh release create v0.1.0 --generate-notes --title "v0.1.0 - Initial Release"
```

**Step 5: Commit**

```bash
git add README.md Sources/Resources/
git commit -m "docs: add README and app icon assets"
```

---

### Task 12: CLAUDE.md for project

**Files:**
- Create: `CLAUDE.md`

**Step 1: Write project-specific CLAUDE.md**

Include build commands, project structure, coding conventions for Swift, and testing approach.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add project CLAUDE.md"
```
