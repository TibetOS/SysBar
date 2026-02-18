# SysBar

macOS menu bar app for real-time system resource monitoring.

## Build & Test

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift run SysBar               # Run the app
```

## Project Structure

- `Sources/SysBarApp.swift` — App entry point with MenuBarExtra
- `Sources/Models/` — SystemMetrics (data structs), AppState (observable state)
- `Sources/Services/SystemMonitor.swift` — Actor collecting all metrics via syscalls
- `Sources/Views/` — SysBarPanel, MetricRow, SparkLine
- `Sources/Utilities/Formatters.swift` — Byte/speed/percent formatting

## Conventions

- Swift 6 strict concurrency (actors, Sendable)
- macOS 15+ minimum deployment target
- No third-party dependencies
- All system data via direct syscalls (Mach, IOKit, POSIX) — never shell out
- Files under 500 lines
- Use `struct` for data, `actor` for mutable shared state, `enum` for namespaces
