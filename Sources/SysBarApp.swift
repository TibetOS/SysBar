import SwiftUI

@main
struct SysBarApp: App {
    var body: some Scene {
        MenuBarExtra("SysBar", systemImage: "chart.bar.fill") {
            Text("SysBar - Loading...")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
