import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("alertsEnabled") private var alertsEnabled: Bool = false
    @AppStorage("cpuThreshold") private var cpuThreshold: Double = 0.90
    @AppStorage("ramThreshold") private var ramThreshold: Double = 0.90
    @AppStorage("historyMinutes") private var historyMinutes: Int = 5
    @State private var updateChecker = UpdateChecker()

    var body: some View {
        Form {
            generalSection
            alertsSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Picker("Refresh Rate", selection: $refreshInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }

            Picker("History Duration", selection: $historyMinutes) {
                Text("1 minute").tag(1)
                Text("5 minutes").tag(5)
                Text("10 minutes").tag(10)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }
        }
    }

    private var alertsSection: some View {
        Section("Alerts") {
            Toggle("Enable Threshold Alerts", isOn: $alertsEnabled)
            if alertsEnabled {
                HStack {
                    Text("CPU Alert")
                    Spacer()
                    Text("\(Int(cpuThreshold * 100))%")
                        .foregroundStyle(.secondary).frame(width: 40)
                    Slider(value: $cpuThreshold, in: 0.5...1.0, step: 0.05)
                        .frame(width: 150)
                }
                HStack {
                    Text("RAM Alert")
                    Spacer()
                    Text("\(Int(ramThreshold * 100))%")
                        .foregroundStyle(.secondary).frame(width: 40)
                    Slider(value: $ramThreshold, in: 0.5...1.0, step: 0.05)
                        .frame(width: 150)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "v\(UpdateChecker.currentVersion)")
            LabeledContent("GitHub") {
                Link("TibetOS/SysBar",
                     destination: URL(string: "https://github.com/TibetOS/SysBar")!)
            }
            Button(action: { updateChecker.checkForUpdates() }) {
                HStack(spacing: 6) {
                    if updateChecker.isChecking { ProgressView().controlSize(.small) }
                    Text(updateChecker.isChecking ? "Checking..." : "Check for Updates...")
                }
            }
            .disabled(updateChecker.isChecking)
        }
    }
}
