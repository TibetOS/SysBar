import SwiftUI

struct MetricRow: View {
    let label: String
    let icon: String
    let value: Double          // 0.0 - 1.0
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(label)
                .frame(width: 40, alignment: .leading)
                .font(.system(.caption, design: .monospaced))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(MetricColor.usage(value))
                        .frame(
                            width: geo.size.width
                                * min(max(CGFloat(value), 0), 1)
                        )
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .frame(height: 20)
    }

}
