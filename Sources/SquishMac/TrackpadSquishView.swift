import AppKit
import SwiftUI

struct TrackpadSquishView: View {
    @ObservedObject var state: TrackpadInteractionState
    @ObservedObject var settings: SettingsStore

    let onGesture: (TrackpadGestureTrigger) -> Void
    let onExportRecording: () -> Void
    let onOpenSystemSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Picker("Mode", selection: modeBinding) {
                    ForEach(TrackpadMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                materialProfilePicker

                TrackpadTouchSurface(
                    state: state,
                    tuning: settings.trackpadTuning(
                        for: activeMaterialProfile
                    ),
                    interactionRules: activeMaterialProfile.effectiveInteractionRules,
                    onGesture: onGesture
                )
                .frame(height: 300)

                liveMetrics

                Divider()

                gestureGuardControls

                Divider()

                tuningControls
                    .disabled(state.isRecording)

                Divider()

                recordingControls
            }
            .padding(20)
        }
        .frame(width: 620, height: 790)
        .onAppear {
            state.mode = settings.trackpadMode
        }
        .onChange(of: settings.trackpadMode) { newMode in
            state.mode = newMode
        }
        .onChange(of: settings.selectedSlimeMaterialProfileID) { _ in
            state.cancelCurrentGesture()
        }
        .onChange(of: settings.selectedWaxMaterialProfileID) { _ in
            state.cancelCurrentGesture()
        }
    }

    private var modeBinding: Binding<TrackpadMode> {
        Binding(
            get: { state.mode },
            set: { newMode in
                state.mode = newMode
                settings.trackpadMode = newMode
            }
        )
    }

    private var activeMaterialProfile: SlimeMaterialProfile {
        settings.selectedMaterialProfile(for: state.mode)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trackpad Squish")
                    .font(.title2.weight(.semibold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(state.inputEventCount > 0 ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(state.pressureStatus)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("On", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
        }
    }

    private var materialProfilePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if state.mode == .sixFingerSlime {
                Picker(
                    "Slime material",
                    selection: $settings.selectedSlimeMaterialProfileID
                ) {
                    ForEach(SlimeMaterialProfile.runtimeSlimeProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Picker(
                    "Wax material",
                    selection: $settings.selectedWaxMaterialProfileID
                ) {
                    ForEach(SlimeMaterialProfile.runtimeWaxProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Text(activeMaterialProfile.effectiveInteractionRules.interactionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let tuning = settings.trackpadTuning(
                for: activeMaterialProfile
            )
            Text(
                String(
                    format: "Profile-adjusted response %.2fx, sound density %.2fx",
                    tuning.response,
                    tuning.soundDensity
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var liveMetrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                metric("Fingers", "\(state.fingerCount)")
                metric("Pressure", String(format: "%.2f", state.pressure))
                metric("Movement", String(format: "%.2f", state.movement))
                metric("Intensity", String(format: "%.2f", state.liveIntensity))
            }

            ProgressView(value: state.liveIntensity, total: 1.0)

            HStack(spacing: 16) {
                if state.isBarPungReady {
                    Label("Bar-pung ready: close and press", systemImage: "circle.grid.cross.fill")
                        .lineLimit(1)
                } else {
                    Label(state.lastGestureLabel, systemImage: "waveform")
                        .lineLimit(1)
                }
                Spacer()
                Text("Stage \(state.forceStage)")
                Text("Peak \(String(format: "%.2f", state.peakPressure))")
                Text("Events \(state.gestureCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var tuningControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Response")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    settings.resetTrackpadTuning()
                }
            }

            settingSlider(
                title: "Touch response",
                value: $settings.trackpadResponse,
                range: SettingsStore.trackpadResponseRange,
                format: "%.2fx"
            )

            settingSlider(
                title: "Sound density",
                value: $settings.trackpadSoundDensity,
                range: SettingsStore.soundDensityRange,
                format: "%.2fx"
            )

            settingSlider(
                title: "Master volume",
                value: $settings.masterVolume,
                range: SettingsStore.masterVolumeRange,
                format: "%.0f%%",
                displayMultiplier: 100
            )

            Toggle("Wax crack and crush haptics", isOn: $settings.isHapticFeedbackEnabled)
        }
    }

    private var gestureGuardControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(
                    "Protect against system trackpad gestures",
                    isOn: $settings.isSystemGestureGuardEnabled
                )
                Spacer()
                Button("Open System Settings", action: onOpenSystemSettings)
            }

            Text("If macOS still changes desktops, turn off Trackpad > More Gestures > Swipe between full-screen applications and Mission Control while testing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Input Recording")
                        .font(.headline)
                    Text("\(state.recordedSampleCount) samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                if state.isRecording {
                    Button("Stop") {
                        state.stopRecording()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Record") {
                        state.startRecording(
                            tuning: settings.trackpadTuning(
                                for: activeMaterialProfile
                            ),
                            materialProfileID: activeMaterialProfile.id
                        )
                    }
                }

                Button("Export JSON", action: onExportRecording)
                    .disabled(!state.hasRecording)

                Button("Clear") {
                    state.clearRecording()
                }
                .disabled(!state.hasRecording && !state.isRecording)

                Button("Reset Diagnostics") {
                    state.reset()
                }
            }

            if state.recordingAtCapacity {
                Text("Recording stopped at the 36,000-sample safety limit. Export or clear the session.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        displayMultiplier: Double = 1
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue * displayMultiplier))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
    }
}

private struct TrackpadTouchSurface: NSViewRepresentable {
    let state: TrackpadInteractionState
    let tuning: TrackpadTuning
    let interactionRules: SlimeInteractionRules
    let onGesture: (TrackpadGestureTrigger) -> Void

    func makeNSView(context: Context) -> TrackpadTouchNSView {
        let view = TrackpadTouchNSView()
        view.state = state
        view.tuning = tuning
        view.interactionRules = interactionRules
        view.onGesture = onGesture
        view.configurePressure(for: state.mode)
        return view
    }

    func updateNSView(_ nsView: TrackpadTouchNSView, context: Context) {
        nsView.state = state
        nsView.tuning = tuning
        nsView.interactionRules = interactionRules
        nsView.onGesture = onGesture
        nsView.configurePressure(for: state.mode)
        nsView.needsDisplay = true
    }
}

private final class TrackpadTouchNSView: NSView {
    var state: TrackpadInteractionState?
    var tuning: TrackpadTuning = .standard
    var interactionRules: SlimeInteractionRules = .standard
    var onGesture: ((TrackpadGestureTrigger) -> Void)?

    private var inputAccumulator = TrackpadInputAccumulator()
    private var configuredPressureMode: TrackpadMode?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        acceptsTouchEvents = true
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        setAccessibilityRole(.group)
        setAccessibilityLabel("Pressure-sensitive squish surface")
    }

    func configurePressure(for mode: TrackpadMode) {
        guard configuredPressureMode != mode else {
            return
        }

        let behavior: NSEvent.PressureBehavior = mode == .sixFingerSlime
            ? .primaryGeneric
            : .primaryDeepClick
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: behavior)
        configuredPressureMode = mode
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }

        super.viewWillMove(toWindow: newWindow)

        if let newWindow {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: newWindow
            )
        }
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        backgroundPath.fill()

        guard let state else {
            return
        }

        let positions = state.touchPoints.map { point in
            CGPoint(
                x: bounds.minX + CGFloat(point.x) * bounds.width,
                y: bounds.minY + CGFloat(point.y) * bounds.height
            )
        }

        if state.mode == .sixFingerSlime {
            drawSlime(at: positions, intensity: state.liveIntensity, pressure: state.pressure)
        } else {
            drawWax(at: positions, intensity: state.liveIntensity, pressure: state.pressure)
        }

        if positions.isEmpty {
            drawEmptyState(mode: state.mode)
        }

        drawStatus(fingerCount: state.fingerCount, target: state.mode.targetFingerCount)
    }

    override func touchesBegan(with event: NSEvent) {
        publishTouches(from: event)
    }

    override func touchesMoved(with event: NSEvent) {
        publishTouches(from: event)
    }

    override func touchesEnded(with event: NSEvent) {
        publishTouches(from: event)
    }

    override func touchesCancelled(with event: NSEvent) {
        clearInput()
    }

    override func pressureChange(with event: NSEvent) {
        let frame = inputAccumulator.updatePressure(
            Double(event.pressure),
            forceStage: event.stage
        )
        publish(frame: frame, isPressureEvent: true)
    }

    override func mouseDown(with event: NSEvent) {
        let pressure = Double(event.pressure).clamped(to: 0.0...1.0)
        let frame = inputAccumulator.updatePressure(
            pressure,
            forceStage: pressure > 0 ? 1 : 0
        )
        publish(frame: frame, isPressureEvent: pressure > 0)
    }

    override func mouseDragged(with event: NSEvent) {
        let pressure = Double(event.pressure).clamped(to: 0.0...1.0)
        let frame = inputAccumulator.updatePressure(
            pressure,
            forceStage: pressure > 0 ? 1 : 0
        )
        publish(frame: frame, isPressureEvent: pressure > 0)
    }

    override func mouseUp(with event: NSEvent) {
        publish(frame: inputAccumulator.updatePressure(0, forceStage: 0))
    }

    override func scrollWheel(with event: NSEvent) {}

    override func swipe(with event: NSEvent) {}

    override func magnify(with event: NSEvent) {}

    override func rotate(with event: NSEvent) {}

    override func smartMagnify(with event: NSEvent) {}

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        true
    }

    @objc private func windowDidResignKey() {
        clearInput()
    }

    private func publishTouches(from event: NSEvent) {
        let touchSet: Set<NSTouch> = event.touches(matching: .touching, in: self)
        let points = touchSet.map { touch -> TrackpadTouchPoint in
            let position = touch.normalizedPosition
            return TrackpadTouchPoint(
                id: "\(touch.identity.hash)-\(String(describing: touch.identity))",
                x: Double(position.x),
                y: Double(position.y)
            )
        }
        .sorted { $0.id < $1.id }

        publish(frame: inputAccumulator.updateTouches(points))
    }

    private func publish(frame: TrackpadInputFrame, isPressureEvent: Bool = false) {
        guard let state else {
            return
        }

        let trigger = state.update(
            fingerCount: frame.touchPoints.count,
            pressure: frame.pressure,
            forceStage: frame.forceStage,
            movement: frame.movement,
            spread: frame.spread,
            touchPoints: frame.touchPoints,
            tuning: tuning,
            interactionRules: interactionRules,
            isPressureEvent: isPressureEvent
        )
        needsDisplay = true

        if let trigger {
            onGesture?(trigger)
        }
    }

    private func clearInput() {
        inputAccumulator.clear()
        state?.cancelCurrentGesture()
        needsDisplay = true
    }

    private func drawSlime(at positions: [CGPoint], intensity: Double, pressure: Double) {
        let slimeColor = NSColor(red: 0.18, green: 0.68, blue: 0.45, alpha: 1)
        if positions.count >= 2 {
            let connectionPath = NSBezierPath()
            connectionPath.lineCapStyle = .round
            connectionPath.lineJoinStyle = .round
            connectionPath.lineWidth = 18 + CGFloat(pressure) * 28

            for leftIndex in 0..<positions.count {
                for rightIndex in (leftIndex + 1)..<positions.count {
                    connectionPath.move(to: positions[leftIndex])
                    connectionPath.line(to: positions[rightIndex])
                }
            }

            slimeColor.withAlphaComponent(0.12 + CGFloat(intensity) * 0.16).setStroke()
            connectionPath.stroke()
        }

        drawTouchPoints(positions, color: slimeColor, pressure: pressure)
    }

    private func drawWax(at positions: [CGPoint], intensity: Double, pressure: Double) {
        let waxColor = NSColor(red: 0.95, green: 0.38, blue: 0.48, alpha: 1)
        drawTouchPoints(positions, color: waxColor, pressure: pressure)

        guard positions.count == 2 else {
            return
        }

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineWidth = 8 + CGFloat(pressure) * 24
        path.move(to: positions[0])
        path.line(to: positions[1])
        waxColor.withAlphaComponent(0.18 + CGFloat(intensity) * 0.24).setStroke()
        path.stroke()

        if intensity >= 0.62 {
            let midpoint = CGPoint(
                x: (positions[0].x + positions[1].x) / 2,
                y: (positions[0].y + positions[1].y) / 2
            )
            let crack = NSBezierPath()
            crack.lineWidth = 2
            crack.move(to: CGPoint(x: midpoint.x - 18, y: midpoint.y + 24))
            crack.line(to: CGPoint(x: midpoint.x + 4, y: midpoint.y + 5))
            crack.line(to: CGPoint(x: midpoint.x - 5, y: midpoint.y - 10))
            crack.line(to: CGPoint(x: midpoint.x + 20, y: midpoint.y - 28))
            NSColor.labelColor.withAlphaComponent(0.55).setStroke()
            crack.stroke()
        }
    }

    private func drawTouchPoints(_ positions: [CGPoint], color: NSColor, pressure: Double) {
        let diameter = CGFloat(28 + pressure * 34)
        for position in positions {
            let touchRect = NSRect(
                x: position.x - diameter / 2,
                y: position.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            color.withAlphaComponent(0.76).setFill()
            NSBezierPath(ovalIn: touchRect).fill()

            color.withAlphaComponent(0.28).setStroke()
            let haloRect = touchRect.insetBy(dx: -10, dy: -10)
            let halo = NSBezierPath(ovalIn: haloRect)
            halo.lineWidth = 2
            halo.stroke()
        }
    }

    private func drawEmptyState(mode: TrackpadMode) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
        let text = mode == .sixFingerSlime
            ? "Place up to six fingers on the trackpad"
            : "Place two thumbs on the trackpad"
        text.draw(in: bounds.insetBy(dx: 24, dy: bounds.height / 2 - 16), withAttributes: attributes)
    }

    private func drawStatus(fingerCount: Int, target: Int) {
        let text = "\(fingerCount) / \(target) fingers"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: bounds.maxX - size.width - 12, y: bounds.maxY - size.height - 10),
            withAttributes: attributes
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
