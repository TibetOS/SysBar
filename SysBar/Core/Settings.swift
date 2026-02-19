import SwiftUI

@Observable
@MainActor
final class Settings {
    @ObservationIgnored @AppStorage("refreshInterval") var refreshInterval: Double = 2.0
    @ObservationIgnored @AppStorage("alertsEnabled") var alertsEnabled: Bool = false
    @ObservationIgnored @AppStorage("cpuThreshold") var cpuThreshold: Double = 0.90
    @ObservationIgnored @AppStorage("ramThreshold") var ramThreshold: Double = 0.90
    @ObservationIgnored @AppStorage("historyMinutes") var historyMinutes: Int = 5
}
