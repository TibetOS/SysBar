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
    }

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
