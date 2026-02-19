# SysBar v2 — Full Redesign

**Date:** 2026-02-19
**Status:** Approved

## Goals

- Full rewrite of SysBar from scratch
- Clean flat-module architecture (Approach A)
- Simplified metrics: drop GPU (unreliable on Apple Silicon)
- Menu bar with colored health dot (green/yellow/red)
- Proper macOS window with sidebar navigation (replaces floating panel)
- Historical time-series charts for CPU, RAM, Network
- All existing features preserved: threshold alerts, launch at login, disk breakdown, update checker

## Architecture: Flat Modules

```
SysBar/
├── App/
│   └── SysBarApp.swift
├── Core/
│   ├── MetricStore.swift
│   ├── MetricCollector.swift
│   ├── MetricTypes.swift
│   ├── RingBuffer.swift
│   └── Settings.swift
├── Services/
│   ├── AlertService.swift
│   ├── DiskAnalyzer.swift
│   └── UpdateChecker.swift
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarLabel.swift
│   │   └── MenuBarDropdown.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── OverviewSection.swift
│   │   ├── CPUSection.swift
│   │   ├── MemorySection.swift
│   │   ├── NetworkSection.swift
│   │   ├── DiskSection.swift
│   │   └── BatterySection.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── UsageBar.swift
│       ├── SparkLine.swift
│       ├── HistoryChart.swift
│       └── MetricCard.swift
├── Utilities/
│   └── Formatters.swift
├── Assets.xcassets/
├── Info.plist
└── SysBar.entitlements
```

25 source files, each focused and under 150 lines.

## Data Layer

### MetricTypes (pure Sendable structs)

- `CPUMetrics` — totalUsage (0-1), perCore [Double], coreCount
- `RAMMetrics` — used, total, active, wired, compressed (UInt64)
- `DiskMetrics` — used, total (UInt64)
- `NetworkMetrics` — upSpeed, downSpeed, totalSent, totalReceived (UInt64)
- `BatteryMetrics` — level (0-100), isCharging, isPluggedIn, hasBattery, cycleCount, health, temperature
- `SystemInfo` — chipName, macOSVersion, hostname, memorySize
- `SystemSnapshot` — combines all metrics + timestamp

No GPU metrics (dropped — unreliable on Apple Silicon).

### MetricCollector (actor)

Single actor with all syscall logic:
- `collectCPU()` — host_processor_info, delta-based per-core
- `collectRAM()` — host_statistics64 via vm_statistics64
- `collectDisk()` — statvfs("/")
- `collectNetwork()` — getifaddrs, delta-based throughput
- `collectBattery()` — IOKit AppleSmartBattery
- `collectSystemInfo()` — sysctl, ProcessInfo
- `collectSnapshot()` — combines all above

### MetricStore (@Observable, @MainActor)

Single source of truth for all metric data:
- `snapshot: SystemSnapshot?`
- `cpuHistory: RingBuffer<Double>`
- `ramHistory: RingBuffer<Double>`
- `networkUpHistory: RingBuffer<UInt64>`
- `networkDownHistory: RingBuffer<UInt64>`
- Owns the polling loop (reads from Settings.refreshInterval)
- Does NOT manage windows, alerts, or disk scanning

### RingBuffer<T>

Generic fixed-size collection conforming to RandomAccessCollection.
Replaces Array + removeFirst() (O(n)) with O(1) append.
Capacity configurable (e.g., 300 samples = 5 min at 1s interval).

### Settings (@Observable, @AppStorage)

- refreshInterval: Double (1, 2, 5, 10 seconds)
- menuBarStyle: String (reserved for future options)
- alertsEnabled: Bool
- cpuThreshold: Double (0.5-1.0)
- ramThreshold: Double (0.5-1.0)
- historyMinutes: Int (1, 5, 10, 30, 60)

Views bind directly via @AppStorage — no manual onChange/UserDefaults dance.

## Services

### AlertService

- Watches MetricStore snapshots
- Checks thresholds from Settings
- Sends UNNotification with 60s cooldown
- Standalone class, not embedded in store

### DiskAnalyzer (actor)

- Scans ~/Library, /Applications, hidden home dirs
- Returns [DiskEntry] sorted by size
- Called on-demand from DiskSection, not from MetricStore

### UpdateChecker

- Fetches latest release from GitHub API (TibetOS/SysBar)
- Compares versions, shows NSAlert with download option
- Used in Settings and About

## UI Design

### Menu Bar

Colored dot indicator based on system health:
- Green: CPU < 60% AND RAM < 60%
- Yellow: CPU 60-85% OR RAM 60-85%
- Red: CPU > 85% OR RAM > 85%

Click opens compact dropdown with:
- One-line per metric (CPU %, RAM, Net, Disk, Battery)
- "Open SysBar" button
- Settings / About / Quit

### Dashboard Window (NavigationSplitView)

Sidebar sections: Overview, CPU, Memory, Network, Disk, Battery
Detail area shows selected section content.

Sections:
- **Overview** — all metrics at a glance with sparklines
- **CPU** — usage bar + sparkline + per-core grid + history chart
- **Memory** — usage bar + breakdown (active/wired/compressed) + history chart
- **Network** — up/down speeds + totals + history chart
- **Disk** — usage bar + breakdown scanner
- **Battery** — level, health, cycle count, temp (if battery present)

Footer: Settings button, About button, version label.

### Shared Components

- `UsageBar` — reusable colored progress bar with label and detail text
- `SparkLine` — Canvas-based inline mini chart
- `HistoryChart` — larger Canvas-based time-series chart for dashboard
- `MetricCard` — card container with icon, title, value

## Conventions

- Swift 6 strict concurrency
- macOS 15+ deployment target
- No third-party dependencies
- All system data via direct syscalls (Mach, IOKit, POSIX)
- Files under 150 lines
- struct for data, actor for mutable shared state, enum for namespaces
- @Observable for view state, @AppStorage for persistent settings
- Direct init injection (no singletons, no EnvironmentObject)
