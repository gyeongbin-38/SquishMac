import AppKit
import AVFoundation
import SwiftUI

struct CameraSlimeView: View {
    @ObservedObject var controller: CameraSlimeController
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            modePicker
            cameraSurface
            liveMetrics
            controls
        }
        .padding(18)
        .frame(width: 760, height: 680)
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Slime")
                    .font(.title2.weight(.semibold))
                Text(controller.statusText)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Sound", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
        }
    }

    private var modePicker: some View {
        Picker(
            "Material",
            selection: Binding(
                get: { controller.mode },
                set: { controller.setMode($0) }
            )
        ) {
            ForEach(ReferenceMaterialMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var cameraSurface: some View {
        ZStack {
            CameraPreview(session: controller.session)
                .background(Color.black)

            GeometryReader { geometry in
                Canvas { context, size in
                    let points = controller.fingertipPoints.map { point in
                        CGPoint(
                            x: CGFloat(point.x) * size.width,
                            y: (1 - CGFloat(point.y)) * size.height
                        )
                    }
                    drawMaterial(
                        points: points,
                        intensity: controller.liveIntensity,
                        mode: controller.mode,
                        context: &context
                    )
                }
                .accessibilityHidden(true)

                if controller.fingertipPoints.isEmpty {
                    Text(controller.isRunning ? "Show one or two hands to the camera" : "Camera preview stopped")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var liveMetrics: some View {
        HStack(spacing: 22) {
            metric("Hands", "\(controller.handCount)")
            metric("Fingertips", "\(controller.fingertipCount)")
            metric("Movement", String(format: "%.2f", controller.movement))
            metric("Pressure estimate", String(format: "%.2f", controller.pressureEstimate))
            metric("Intensity", String(format: "%.2f", controller.liveIntensity))
        }
    }

    private var controls: some View {
        HStack {
            Label(controller.lastGestureLabel, systemImage: "waveform")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if controller.isRunning {
                Button("Stop Camera") {
                    controller.stop()
                }
            } else {
                Button("Start Camera") {
                    controller.start()
                }
                .buttonStyle(.borderedProminent)
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

    private func drawMaterial(
        points: [CGPoint],
        intensity: Double,
        mode: ReferenceMaterialMode,
        context: inout GraphicsContext
    ) {
        let color: Color = mode == .slime
            ? Color(red: 0.14, green: 0.86, blue: 0.48)
            : Color(red: 1.0, green: 0.30, blue: 0.46)
        let magnitude = CGFloat(intensity)

        if points.count >= 2 {
            var connections = Path()
            for leftIndex in 0..<points.count {
                for rightIndex in (leftIndex + 1)..<points.count {
                    connections.move(to: points[leftIndex])
                    connections.addLine(to: points[rightIndex])
                }
            }
            context.stroke(
                connections,
                with: .color(color.opacity(0.18 + intensity * 0.22)),
                style: StrokeStyle(
                    lineWidth: mode == .slime ? 18 + magnitude * 28 : 8 + magnitude * 18,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        let diameter = 24 + magnitude * 28
        for point in points {
            let rect = CGRect(
                x: point.x - diameter / 2,
                y: point.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.82)))
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -8, dy: -8)),
                with: .color(color.opacity(0.36)),
                lineWidth: 2
            )
        }
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class CameraPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    private func configure() {
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(previewLayer)
    }
}
