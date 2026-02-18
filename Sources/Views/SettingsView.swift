import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Permissions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Full Disk Access")
                        Text("Required to scan all folders in disk breakdown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings...") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                        )
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: "v\(UpdateChecker.currentVersion)")
                LabeledContent("GitHub") {
                    Link("TibetOS/SysBar",
                         destination: URL(string: "https://github.com/TibetOS/SysBar")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 260)
    }
}
