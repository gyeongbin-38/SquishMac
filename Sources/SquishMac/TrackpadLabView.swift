import AppKit
import SwiftUI

struct TrackpadLabView: View {
    @ObservedObject var state: TrackpadInteractionState

    let onGesture: (TrackpadGestureTrigger) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Picker("Mode", selection: $state.mode) {
                ForEach(TrackpadMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TrackpadTouchSurface(state: state, onGesture: onGesture)
                .frame(height: 270)

            metrics
        }
        .padding(22)
        .frame(width: 560, height: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Trackpad Lab")
                .font(.title2.weight(.semibold))

            Text("Use the trackpad as a pressure-sensitive squish surface.")
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                metric("Fingers", "\(state.fingerCount)")
                metric("Pressure", String(format: "%.2f", state.pressure))
                metric("Intensity", String(format: "%.2f", state.liveIntensity))
            }

            ProgressView(value: state.liveIntensity, total: 1.0)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Movement")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.3f", state.movement))
                        .monospacedDigit()
                }

                GridRow {
                    Text("Spread")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.3f", state.spread))
                        .monospacedDigit()
                }

                GridRow {
                    Text("Last gesture")
                        .foregroundStyle(.secondary)
                    Text(state.lastGestureLabel)
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrackpadTouchSurface: NSViewRepresentable {
    let state: TrackpadInteractionState
    let onGesture: (TrackpadGestureTrigger) -> Void

    func makeNSView(context: Context) -> TrackpadTouchNSView {
        let view = TrackpadTouchNSView()
        view.state = state
        view.onGesture = onGesture
        return view
    }

    func updateNSView(_ nsView: TrackpadTouchNSView, context: Context) {
        nsView.state = state
        nsView.onGesture = onGesture
        nsView.needsDisplay = true
    }
}

private final class TrackpadTouchNSView: NSView {
    var state: TrackpadInteractionState?
    var onGesture: ((TrackpadGestureTrigger) -> Void)?

    private var lastPressure: Double = 0
    private var previousPositions: [CGPoint] = []

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        acceptsTouchEvents = true
        wantsRestingTouches = true
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.window?.makeFirstResponder(self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        let modeTitle = state?.mode.title ?? "Trackpad"
        let text = "\(modeTitle)\nTouch here, then press and knead on the trackpad."
        let rect = bounds.insetBy(dx: 24, dy: 96)
        text.draw(in: rect, withAttributes: attributes)
    }

    override func touchesBegan(with event: NSEvent) {
        publish(event: event)
    }

    override func touchesMoved(with event: NSEvent) {
        publish(event: event)
    }

    override func touchesEnded(with event: NSEvent) {
        publish(event: event, forceFingerCount: 0)
    }

    override func touchesCancelled(with event: NSEvent) {
        publish(event: event, forceFingerCount: 0)
    }

    override func pressureChange(with event: NSEvent) {
        lastPressure = Double(event.pressure).clamped(to: 0.0...1.0)
        publish(event: event)
    }

    override func mouseDown(with event: NSEvent) {
        lastPressure = Double(event.pressure).clamped(to: 0.0...1.0)
        publish(event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        lastPressure = Double(event.pressure).clamped(to: 0.0...1.0)
        publish(event: event)
    }

    override func mouseUp(with event: NSEvent) {
        lastPressure = 0
        publish(event: event, forceFingerCount: 0)
    }

    private func publish(event: NSEvent, forceFingerCount: Int? = nil) {
        let touches = Array(event.touches(matching: .touching, in: self))
        let positions = touches
            .map(\.normalizedPosition)
            .sorted { lhs, rhs in
                lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
            }

        let fingerCount = forceFingerCount ?? positions.count
        let movement = movementAmount(current: positions, previous: previousPositions)
        let spread = spreadAmount(positions)
        previousPositions = positions

        DispatchQueue.main.async { [weak self] in
            guard let self, let state = self.state else {
                return
            }

            let trigger = state.update(
                fingerCount: fingerCount,
                pressure: self.lastPressure,
                movement: movement,
                spread: spread
            )

            if let trigger {
                self.onGesture?(trigger)
            }
        }
    }

    private func movementAmount(current: [CGPoint], previous: [CGPoint]) -> Double {
        guard !current.isEmpty, !previous.isEmpty else {
            return 0
        }

        let count = min(current.count, previous.count)
        let total = (0..<count).reduce(0.0) { partial, index in
            partial + current[index].distance(to: previous[index])
        }

        return (total / Double(count) * 10.0).clamped(to: 0.0...1.0)
    }

    private func spreadAmount(_ positions: [CGPoint]) -> Double {
        guard positions.count >= 2 else {
            return 0
        }

        var maxDistance = 0.0
        for leftIndex in 0..<positions.count {
            for rightIndex in (leftIndex + 1)..<positions.count {
                maxDistance = max(maxDistance, positions[leftIndex].distance(to: positions[rightIndex]))
            }
        }

        return maxDistance.clamped(to: 0.0...1.0)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> Double {
        let dx = Double(x - other.x)
        let dy = Double(y - other.y)
        return sqrt(dx * dx + dy * dy)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
