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
- `SysBar/App/SysBarApp.swift` — App entry point with MenuBarExtra + Window + Settings scenes
- `SysBar/Core/` — MetricTypes, RingBuffer, Settings, MetricCollector (syscalls), MetricStore
- `SysBar/Services/` — AlertService, DiskAnalyzer, UpdateChecker
- `SysBar/Views/MenuBar/` — MenuBarLabel (colored health dot), MenuBarDropdown (compact summary)
- `SysBar/Views/Dashboard/` — DashboardView (NavigationSplitView) + section views (Overview, CPU, Memory, Network, Disk, Battery)
- `SysBar/Views/Settings/` — SettingsView (AppStorage-based preferences)
- `SysBar/Views/Shared/` — UsageBar, SparkLine, MetricCard, HistoryChart
- `SysBar/Utilities/Formatters.swift` — MetricFormatter + MetricColor
- `SysBar/Assets.xcassets/` — App icon and asset catalog
- `SysBar/Info.plist` — App metadata (uses Xcode build variables)
- `SysBar/SysBar.entitlements` — App entitlements (sandbox disabled for syscall access)

## Conventions

- Swift 6 strict concurrency (actors, Sendable)
- macOS 15+ minimum deployment target
- No third-party dependencies
- All system data via direct syscalls (Mach, IOKit, POSIX) — never shell out
- Files under 150 lines (MetricCollector exception at ~230 lines)
- Use `struct` for data, `actor` for mutable shared state, `enum` for namespaces
- @Observable for view state, @AppStorage for persistent settings
- Direct init injection (no singletons, no EnvironmentObject)
- Version is set in `project.yml` → `MARKETING_VERSION` (propagates to Info.plist)
