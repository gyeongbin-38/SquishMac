import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import Vision

final class CameraSlimeController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "Camera is stopped."
    @Published private(set) var handCount = 0
    @Published private(set) var fingertipCount = 0
    @Published private(set) var movement = 0.0
    @Published private(set) var pressureEstimate = 0.0
    @Published private(set) var liveIntensity = 0.0
    @Published private(set) var isBarPungReady = false
    @Published private(set) var fingertipPoints: [NormalizedPosePoint] = []
    @Published private(set) var lastGestureLabel = "Waiting for a gesture"
    @Published private(set) var mode: ReferenceMaterialMode = .slime

    let session = AVCaptureSession()
    var onGesture: ((TrackpadGestureTrigger) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.squishmac.camera.session")
    private let visionQueue = DispatchQueue(
        label: "com.squishmac.camera.vision",
        qos: .userInteractive
    )
    private let videoOutput = AVCaptureVideoDataOutput()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()
    private var isConfigured = false
    private var isStarting = false
    private var featureExtractor = HandMotionFeatureExtractor()
    private var gestureEngine = ReferenceGestureInferenceEngine(mode: .slime)
    private var selectedCameraTuning = CameraGestureTuning.standard
    private var selectedInteractionRules = SlimeInteractionRules.standard
    private var activeCameraTuning = CameraGestureTuning.standard
    private var activeInteractionRules = SlimeInteractionRules.standard
    private var lastAnalyzedTime = -Double.infinity

    func start() {
        guard !isRunning, !isStarting else {
            return
        }
        isStarting = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            statusText = "Waiting for camera permission..."
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.isStarting = false
                        self.statusText = "Camera access was denied. Enable it in Privacy & Security."
                    }
                }
            }
        case .denied, .restricted:
            isStarting = false
            statusText = "Camera access is unavailable. Enable it in Privacy & Security."
        @unknown default:
            isStarting = false
            statusText = "Camera authorization could not be determined."
        }
    }

    func stop() {
        isStarting = false
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusText = "Camera is stopped."
                self.clearPublishedTracking()
            }
        }
    }

    func setMode(_ mode: ReferenceMaterialMode) {
        guard self.mode != mode else {
            return
        }
        self.mode = mode
        let tuning = selectedCameraTuning
        let rules = selectedInteractionRules
        visionQueue.async { [weak self] in
            self?.featureExtractor.reset()
            self?.activeCameraTuning = tuning
            self?.activeInteractionRules = rules
            self?.gestureEngine = ReferenceGestureInferenceEngine(
                mode: mode,
                cameraTuning: tuning,
                interactionRules: rules
            )
            self?.lastAnalyzedTime = -Double.infinity
        }
        clearPublishedTracking()
    }

    func setMaterialProfile(_ profile: SlimeMaterialProfile) {
        selectedCameraTuning = profile.effectiveCameraTuning
        selectedInteractionRules = profile.effectiveInteractionRules
        let tuning = selectedCameraTuning
        let rules = selectedInteractionRules
        let mode = self.mode

        visionQueue.async { [weak self] in
            self?.featureExtractor.reset()
            self?.activeCameraTuning = tuning
            self?.activeInteractionRules = rules
            self?.gestureEngine = ReferenceGestureInferenceEngine(
                mode: mode,
                cameraTuning: tuning,
                interactionRules: rules
            )
            self?.lastAnalyzedTime = -Double.infinity
        }
        clearPublishedTracking()
    }

    private func configureAndStart() {
        statusText = "Starting camera..."
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            do {
                if !self.isConfigured {
                    try self.configureSession()
                }
                guard !self.session.isRunning else {
                    DispatchQueue.main.async {
                        self.isStarting = false
                        self.isRunning = true
                        self.statusText = "Camera hand tracking is active."
                    }
                    return
                }

                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isStarting = false
                    self.isRunning = self.session.isRunning
                    self.statusText = self.session.isRunning
                        ? "Camera hand tracking is active."
                        : "The camera could not be started."
                }
            } catch {
                DispatchQueue.main.async {
                    self.isStarting = false
                    self.isRunning = false
                    self.statusText = error.localizedDescription
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw CameraSlimeError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraSlimeError.cannotAddCamera
        }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(videoOutput) else {
            throw CameraSlimeError.cannotAddVideoOutput
        }
        session.addOutput(videoOutput)
        isConfigured = true
    }

    private func publish(
        frame: HandMotionFrame,
        gesture: ReferenceGestureKind?,
        intensity: Double,
        isBarPungReady: Bool
    ) {
        let points = frame.hands.flatMap { hand in
            hand.joints
                .filter { $0.key.isFingertip }
                .map(\.value)
        }
        handCount = frame.handCount
        fingertipCount = frame.fingertipCount
        movement = frame.movement
        pressureEstimate = frame.pressureEstimate
        liveIntensity = intensity
        self.isBarPungReady = isBarPungReady
        fingertipPoints = points

        guard let gesture else {
            return
        }
        lastGestureLabel = gesture.title
    }

    private func clearPublishedTracking() {
        handCount = 0
        fingertipCount = 0
        movement = 0
        pressureEstimate = 0
        liveIntensity = 0
        isBarPungReady = false
        fingertipPoints = []
        lastGestureLabel = "Waiting for a gesture"
    }
}

extension CameraSlimeController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard timestamp.isFinite, timestamp - lastAnalyzedTime >= 1.0 / 15.0 else {
            return
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        lastAnalyzedTime = timestamp

        do {
            let handler = VNImageRequestHandler(
                cvPixelBuffer: imageBuffer,
                orientation: .up,
                options: [:]
            )
            try handler.perform([handRequest])
            let sample = try VisionHandPoseExtractor.sample(
                timestamp: timestamp,
                observations: handRequest.results ?? []
            )
            let frame = featureExtractor.process(sample)
            let inferredGesture = gestureEngine.process(frame)
            let isBarPungReady = gestureEngine.isBarPungPrepared
            let responsiveMovement = (
                frame.movement * activeCameraTuning.response
            ).clamped(to: 0.0...1.0)
            let responsivePressure = (
                frame.pressureEstimate * activeCameraTuning.response
            ).clamped(to: 0.0...1.0)
            let intensity = (
                responsiveMovement * 0.38
                    + responsivePressure * 0.42
                    + Double(min(frame.fingertipCount, 10)) / 10.0 * 0.20
            ).clamped(to: 0.0...1.0)
            let trigger = inferredGesture.map {
                TrackpadGestureTrigger(
                    kind: $0.kind.soundKind,
                    intensity: $0.intensity,
                    label: "Camera \($0.kind.title)",
                    soundPackIDOverride: activeInteractionRules.soundPackID(
                        for: $0.kind.soundKind
                    ),
                    volumeScale: activeInteractionRules.effectiveVolumeScale
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRunning else {
                    return
                }
                self.publish(
                    frame: frame,
                    gesture: inferredGesture?.kind,
                    intensity: intensity,
                    isBarPungReady: isBarPungReady
                )
                if let trigger {
                    self.onGesture?(trigger)
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.statusText = "Hand tracking error: \(error.localizedDescription)"
            }
        }
    }
}

enum CameraSlimeError: LocalizedError {
    case cameraUnavailable
    case cannotAddCamera
    case cannotAddVideoOutput

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No camera is available on this Mac."
        case .cannotAddCamera:
            return "SquishMac could not connect the camera input."
        case .cannotAddVideoOutput:
            return "SquishMac could not read camera frames."
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
