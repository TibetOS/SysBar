#!/usr/bin/env swift
import AppKit

// Render gauge SF Symbol into an app icon
let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let iconsetPath = "/tmp/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let cgSize = CGFloat(size)
    let image = NSImage(size: NSSize(width: cgSize, height: cgSize))
    image.lockFocus()

    // Background: rounded rect with gradient
    let rect = NSRect(x: 0, y: 0, width: cgSize, height: cgSize)
    let cornerRadius = cgSize * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Dark gradient background
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: 270)

    // Subtle border
    NSColor(calibratedWhite: 0.25, alpha: 0.5).setStroke()
    path.lineWidth = cgSize * 0.01
    path.stroke()

    // Draw SF Symbol
    let symbolSize = cgSize * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolRect = symbol.size
        let x = (cgSize - symbolRect.width) / 2
        let y = (cgSize - symbolRect.height) / 2
        // Tint the symbol white
        let tinted = NSImage(size: symbolRect, flipped: false) { drawRect in
            symbol.draw(in: drawRect)
            NSColor.white.set()
            drawRect.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: NSRect(x: x, y: y, width: symbolRect.width, height: symbolRect.height))
    }

    image.unlockFocus()

    // Save PNG
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(name)")
        continue
    }
    try png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

// Convert iconset to icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✓ AppIcon.icns created")
} else {
    print("✗ iconutil failed with status \(process.terminationStatus)")
}

// Cleanup
try? fm.removeItem(atPath: iconsetPath)
