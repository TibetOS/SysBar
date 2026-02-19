import Foundation
import UserNotifications

@MainActor
final class AlertService {
    private let settings: Settings
    private var lastCPUAlert: Date = .distantPast
    private var lastRAMAlert: Date = .distantPast
    private let cooldown: TimeInterval = 60

    init(settings: Settings) {
        self.settings = settings
        requestPermission()
    }

    func check(_ snapshot: SystemSnapshot) {
        guard settings.alertsEnabled else { return }
        let now = Date()

        if snapshot.cpu.totalUsage >= settings.cpuThreshold,
           now.timeIntervalSince(lastCPUAlert) > cooldown {
            lastCPUAlert = now
            send(title: "High CPU Usage",
                 body: "CPU at \(MetricFormatter.percent(snapshot.cpu.totalUsage))")
        }

        if snapshot.ram.usagePercent >= settings.ramThreshold,
           now.timeIntervalSince(lastRAMAlert) > cooldown {
            lastRAMAlert = now
            send(title: "High RAM Usage",
                 body: "RAM at \(MetricFormatter.percent(snapshot.ram.usagePercent))")
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
