import SwiftUI

struct HistoryChart: View {
    let values: [Double]        // normalized 0.0–1.0
    let label: String
    var height: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                Canvas { context, size in
                    drawGrid(context: context, size: size)
                    drawLine(context: context, size: size)
                }
                .frame(height: height)

                if let last = values.last {
                    Text(MetricFormatter.percent(last))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            }

            HStack {
                Text("older")
                Spacer()
                Text("now")
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.quaternary)
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for i in 1..<4 {
            let y = size.height * CGFloat(i) / 4
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
        }
    }

    private func drawLine(context: GraphicsContext, size: CGSize) {
        guard values.count >= 2 else { return }
        let stepX = size.width / CGFloat(values.count - 1)

        var path = Path()
        for (i, value) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = size.height - (CGFloat(value) * size.height)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        let color = MetricColor.usage(values.last ?? 0)
        context.stroke(path, with: .color(color), lineWidth: 2)

        var fill = path
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .color(color.opacity(0.1)))
    }
}
