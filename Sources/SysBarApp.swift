import SwiftUI

@main
struct SysBarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SysBarPanel(state: appState)
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
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
}
