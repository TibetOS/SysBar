import SwiftUI

struct MenuBarLabel: View {
    let store: MetricStore

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 10))
            .foregroundStyle(dotColor)
    }

    private var dotColor: Color {
        guard let snap = store.snapshot else { return .gray }
        return MetricColor.health(snap.cpu.totalUsage, snap.ram.usagePercent)
    }
}
