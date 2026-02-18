#!/usr/bin/env swift
import AppKit

let width: CGFloat = 500
let height: CGFloat = 260
let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()

// Dark gradient background
let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1.0),
    NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0),
])!
gradient.draw(in: bgRect, angle: 270)

// Subtle top border line
NSColor(calibratedWhite: 0.25, alpha: 0.3).setFill()
NSRect(x: 0, y: height - 1, width: width, height: 1).fill()

// Arrow from app position to Applications position
let arrowY = height - 130.0
let arrowStartX: CGFloat = 175
let arrowEndX: CGFloat = 325
let arrowPath = NSBezierPath()
arrowPath.lineWidth = 2.5
arrowPath.lineCapStyle = .round

// Arrow shaft
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 10, y: arrowY))

// Arrow head
arrowPath.move(to: NSPoint(x: arrowEndX - 20, y: arrowY + 10))
arrowPath.line(to: NSPoint(x: arrowEndX - 5, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 20, y: arrowY - 10))

NSColor(calibratedWhite: 0.6, alpha: 0.8).setStroke()
arrowPath.stroke()

// "Drag to install" text
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 1.0),
    .paragraphStyle: paragraphStyle,
]
let text = "Drag to Applications to install"
let textRect = NSRect(x: 0, y: 30, width: width, height: 24)
text.draw(in: textRect, withAttributes: attrs)

image.unlockFocus()

// Save as PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to render")
    exit(1)
}

let outputPath = "scripts/dmg-background.png"
try png.write(to: URL(fileURLWithPath: outputPath))
print("✓ \(outputPath) created (\(Int(width))x\(Int(height)))")
