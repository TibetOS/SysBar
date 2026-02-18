import SwiftUI

@main
struct SysBarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SysBarPanel(state: appState)
        } label: {
            SparkLine(values: appState.cpuHistory)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
