import SwiftUI

@main
struct SysBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = Settings()
    @State private var store: MetricStore
    @State private var alertService: AlertService

    init() {
        let s = Settings()
        let m = MetricStore(settings: s)
        _settings = State(initialValue: s)
        _store = State(initialValue: m)
        _alertService = State(initialValue: AlertService(settings: s))
        m.startPolling()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarDropdown(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("SysBar", id: "dashboard") {
            DashboardView(store: store, settings: settings)
        }
        .defaultSize(width: 700, height: 500)
        .defaultPosition(.center)

        SwiftUI.Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
