# SysBar

macOS menu bar app for real-time system resource monitoring.

## Build & Test

```bash
# Xcode (preferred)
open SysBar.xcodeproj              # Open in Xcode, then Cmd+R

# Command line
xcodebuild -scheme SysBar build    # Debug build
xcodebuild -scheme SysBar -configuration Release build  # Release build

# Regenerate .xcodeproj after adding/removing files
xcodegen generate
```

## Project Structure

- `project.yml` — XcodeGen spec (source of truth for project config)
- `SysBar.xcodeproj/` — Generated Xcode project (regenerate with `xcodegen`)
- `SysBar/SysBarApp.swift` — App entry point with MenuBarExtra
- `SysBar/Models/` — SystemMetrics (data structs), AppState (observable state), Preferences
- `SysBar/Services/` — SystemMonitor (syscalls), DiskAnalyzer, UpdateChecker
- `SysBar/Views/` — SysBarPanel, MetricRow, SparkLine, FloatingPanel/View, Settings, About
- `SysBar/Utilities/Formatters.swift` — Byte/speed/percent formatting
- `SysBar/Assets.xcassets/` — App icon and asset catalog
- `SysBar/Info.plist` — App metadata (uses Xcode build variables)
- `SysBar/SysBar.entitlements` — App entitlements (sandbox disabled for syscall access)

## Conventions

- Swift 6 strict concurrency (actors, Sendable)
- macOS 15+ minimum deployment target
- No third-party dependencies
- All system data via direct syscalls (Mach, IOKit, POSIX) — never shell out
- Files under 500 lines
- Use `struct` for data, `actor` for mutable shared state, `enum` for namespaces
- Version is set in `project.yml` → `MARKETING_VERSION` (propagates to Info.plist)
