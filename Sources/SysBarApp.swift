import SwiftUI

@main
struct SysBarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SysBarPanel(state: appState)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("About SysBar", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Floating Panel") {
                    appState.toggleFloating()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch appState.menuBarDisplay {
        case .iconOnly:
            Image(systemName: "gauge.with.dots.needle.33percent")
        case .cpu:
            if let snap = appState.snapshot {
                Text(MetricFormatter.percent(snap.cpu.totalUsage))
            } else {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
        case .ram:
            if let snap = appState.snapshot {
                Text(MetricFormatter.percent(snap.ram.usagePercent))
            } else {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
        case .network:
            if let snap = appState.snapshot {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9))
                    Text(MetricFormatter.speed(snap.network.bytesPerSecUp))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9))
                    Text(MetricFormatter.speed(snap.network.bytesPerSecDown))
                }
                .font(.system(.caption, design: .monospaced))
            } else {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
        }
    }
}
