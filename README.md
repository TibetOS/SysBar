# SysBar

A lightweight macOS menu bar app that displays real-time system resource usage.

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **CPU** — Total and per-core usage with spark-line history in the menu bar
- **RAM** — Used / total memory in GB
- **GPU** — Apple Silicon GPU utilization percentage
- **Disk** — Boot volume used / total space
- **Network** — Real-time upload and download speeds
- **Battery** — Level, charging status, and power source

## Menu Bar

The menu bar icon shows a live CPU spark-line chart. Click to open the full metrics panel.

## Requirements

- macOS 15+ (Sequoia)
- Apple Silicon Mac
- Xcode 16+ or Swift 6 toolchain

## Build & Run

```bash
# Build
swift build

# Run
swift run SysBar

# Or open in Xcode
open Package.swift
```

## Architecture

- **Pure SwiftUI** — `MenuBarExtra` with `.window` style, no AppKit bridges
- **Zero dependencies** — Uses system APIs only (Mach, IOKit, POSIX)
- **Swift actors** — Thread-safe data collection without manual locks
- **Direct syscalls** — `host_processor_info`, `host_statistics64`, `statvfs`, `getifaddrs`, IOKit registry

### Project Structure

```
Sources/
├── SysBarApp.swift          # Entry point, MenuBarExtra setup
├── Models/
│   ├── SystemMetrics.swift  # Data structs (CPU, RAM, GPU, Disk, Network, Battery)
│   └── AppState.swift       # Observable state with 2-second refresh loop
├── Services/
│   └── SystemMonitor.swift  # Actor collecting all metrics via syscalls
├── Views/
│   ├── SysBarPanel.swift    # Main dropdown panel
│   ├── MetricRow.swift      # Reusable metric + progress bar component
│   └── SparkLine.swift      # Canvas-based CPU spark-line
└── Utilities/
    └── Formatters.swift     # Byte, speed, and percentage formatting
```

## License

MIT
