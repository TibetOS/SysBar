import SwiftUI

struct BatterySection: View {
    let battery: BatteryMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if battery.hasBattery {
                    batteryContent
                } else {
                    noBatteryView
                }
            }
            .padding(20)
        }
        .navigationTitle("Battery")
    }

    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                    .font(.largeTitle)
                    .foregroundStyle(MetricColor.battery(battery.level))
                VStack(alignment: .leading) {
                    Text("\(battery.level)%")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(statusText)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(icon: "heart", title: "Health", value: "\(battery.health)%",
                           color: MetricColor.battery(battery.health))
                MetricCard(icon: "arrow.triangle.2.circlepath", title: "Cycles",
                           value: "\(battery.cycleCount)")
                if battery.temperature > 0 {
                    MetricCard(icon: "thermometer", title: "Temp",
                               value: String(format: "%.1f\u{00B0}C", battery.temperature))
                }
            }
        }
    }

    private var statusText: String {
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged In" }
        return "On Battery"
    }

    private var noBatteryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Battery Detected")
                .font(.headline).foregroundStyle(.secondary)
            Text("This Mac doesn't have a battery.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
