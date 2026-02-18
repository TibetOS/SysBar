# SysBar Design Document

> Date: 2026-02-18
> Status: Approved

## Overview

SysBar is a native macOS menu bar app that displays real-time system resource usage. It lives in the top menu bar with a CPU spark-line icon and opens a clean dropdown panel showing all metrics.

## Requirements

- **Platform**: macOS 15+ (Sequoia), Apple Silicon
- **Language**: Swift with SwiftUI
- **Build**: Swift Package Manager (no Xcode project required)
- **Dependencies**: Zero third-party — system APIs only

## Architecture

### App Lifecycle

```
SysBarApp (@main, SwiftUI App)
├── MenuBarExtra (.window style)
│   ├── Label: Canvas-rendered CPU spark-line (last ~20 samples)
│   └── Content: SysBarPanel
│       ├── CPUSection (per-core bars + total %)
│       ├── RAMSection (used/total bar + GB)
│       ├── GPUSection (Metal utilization + VRAM)
│       ├── DiskSection (boot volume used/total)
│       ├── NetworkSection (↑/↓ speeds)
│       ├── BatterySection (level + charging state)
│       └── Footer (Quit button)
└── No Dock icon (.accessory activation policy)
```

### Data Collection

All metrics collected via a single `SystemMonitor` actor with a 2-second refresh loop.

| Metric | API | Approach |
|--------|-----|----------|
| CPU usage | `host_processor_info()` | Mach host API, per-core ticks delta |
| RAM | `host_statistics64()` | Mach VM stats → active+wired / total |
| GPU | `IOServiceMatching("AGXAccelerator")` | IOKit registry for Apple GPU utilization |
| Disk | `statvfs()` | POSIX call on `/` mount point |
| Network | `getifaddrs()` + `if_data` | Per-interface bytes delta, exclude `lo0` |
| Battery | `IOServiceMatching("AppleSmartBattery")` | IOKit for level, charging, AC power |

### Menu Bar Icon

- Ring buffer of last 20 CPU samples
- SwiftUI `Canvas` → `NSImage` (18pt height, ~60pt width)
- Color: system teal (template-compatible)
- Updates every 2 seconds

### Panel UI

- Fixed width: 300pt
- Each metric: label + progress bar + value text
- Color coding: green (< 60%), yellow (60-85%), red (> 85%)
- Network: auto-scaled speeds (KB/s, MB/s, GB/s)
- Battery: charging icon when plugged in

## Project Structure

```
SysBar/
├── Package.swift
├── Sources/
│   ├── SysBarApp.swift
│   ├── Models/
│   │   └── SystemMetrics.swift
│   ├── Services/
│   │   └── SystemMonitor.swift
│   ├── Views/
│   │   ├── SysBarPanel.swift
│   │   ├── MetricRow.swift
│   │   └── SparkLine.swift
│   └── Utilities/
│       └── Formatters.swift
├── Resources/
│   └── Assets.xcassets/
├── README.md
├── LICENSE
└── .gitignore
```

## Design Decisions

1. **Pure SwiftUI with MenuBarExtra** — Modern, minimal boilerplate, no AppKit bridges needed
2. **Swift actors for data collection** — Thread-safe without manual locks
3. **Direct syscalls over process spawning** — 16x faster, 125x less memory (lesson from PortKiller)
4. **Canvas for spark-line** — GPU-accelerated, smooth rendering
5. **SPM over Xcode project** — Simpler, CLI-buildable, no .xcodeproj noise

## Future (v2)

- Alerts/thresholds with configurable notifications
- Settings panel (refresh rate, visible metrics)
- Launch at login
- Per-core CPU detail view
