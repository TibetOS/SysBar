import SwiftUI

@main
struct SysBarApp: App {
    @State private var appState = AppState()
    @State private var updateChecker = UpdateChecker()

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
    }

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
