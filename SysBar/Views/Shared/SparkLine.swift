import SwiftUI

struct SparkLine<T: BinaryFloatingPoint>: View {
    let values: [T]
    var color: Color = .green
    var height: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let maxVal = values.max() ?? 1
            let normalizer = maxVal > 0 ? maxVal : 1
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (i, value) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - (CGFloat(value / normalizer) * size.height)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            let lineColor = MetricColor.usage(Double(values.last ?? 0))
            context.stroke(path, with: .color(lineColor), lineWidth: 1.5)

            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(lineColor.opacity(0.15)))
        }
        .frame(height: height)
    }
}
