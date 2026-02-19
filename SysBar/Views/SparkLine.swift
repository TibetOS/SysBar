import SwiftUI

struct SparkLine: View {
    let values: [Double]
    let width: CGFloat = 50
    let height: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let stepX = size.width / CGFloat(values.count - 1)
            var path = Path()

            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(value) * size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let color = sparkColor(for: values.last ?? 0)
            context.stroke(path, with: .color(color), lineWidth: 1.5)

            // Fill under the line
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(color.opacity(0.2)))
        }
        .frame(width: width, height: height)
    }

    private func sparkColor(for value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.60 { return .yellow }
        return .green
    }
}
