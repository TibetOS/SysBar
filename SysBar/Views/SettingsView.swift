import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var menuBarDisplay = Preferences.menuBarDisplay
    @State private var refreshRate = Preferences.refreshRate
    @State private var alertsEnabled = Preferences.alertsEnabled
    @State private var cpuThreshold = Preferences.cpuThreshold
    @State private var ramThreshold = Preferences.ramThreshold

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

                Picker("Menu Bar Display", selection: $menuBarDisplay) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .onChange(of: menuBarDisplay) { _, newValue in
                    Preferences.menuBarDisplay = newValue
                }

                Picker("Refresh Rate", selection: $refreshRate) {
                    ForEach(RefreshRate.allCases, id: \.self) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                .onChange(of: refreshRate) { _, newValue in
                    Preferences.refreshRate = newValue
                }
            }

            Section("Alerts") {
                Toggle("Enable Threshold Alerts", isOn: $alertsEnabled)
                    .onChange(of: alertsEnabled) { _, newValue in
                        Preferences.alertsEnabled = newValue
                    }

                if alertsEnabled {
                    HStack {
                        Text("CPU Alert")
                        Spacer()
                        Text("\(Int(cpuThreshold * 100))%")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                        Slider(value: $cpuThreshold, in: 0.5...1.0, step: 0.05)
                            .frame(width: 150)
                            .onChange(of: cpuThreshold) { _, newValue in
                                Preferences.cpuThreshold = newValue
                            }
                    }

                    HStack {
                        Text("RAM Alert")
                        Spacer()
                        Text("\(Int(ramThreshold * 100))%")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                        Slider(value: $ramThreshold, in: 0.5...1.0, step: 0.05)
                            .frame(width: 150)
                            .onChange(of: ramThreshold) { _, newValue in
                                Preferences.ramThreshold = newValue
                            }
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
        .frame(width: 450, height: 420)
    }
}
