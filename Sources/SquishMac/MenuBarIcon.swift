import AppKit

enum MenuBarIcon {
    static func make(isEnabled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let alpha = isEnabled ? 1.0 : 0.35
        let color = NSColor.labelColor.withAlphaComponent(alpha)

        color.setStroke()
        let outline = NSBezierPath(
            roundedRect: NSRect(x: 3.0, y: 4.0, width: 12.0, height: 10.0),
            xRadius: 5.0,
            yRadius: 5.0
        )
        outline.lineWidth = 1.8
        outline.stroke()

        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6.0, y: 7.0, width: 2.5, height: 2.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.0, y: 8.5, width: 2.0, height: 2.0)).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
