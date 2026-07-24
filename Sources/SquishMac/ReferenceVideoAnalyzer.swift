import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import Vision

final class ReferenceVideoAnalyzer {
    static let analysisFramesPerSecond = 15.0

    func analyze(
        videoURL: URL,
        mode: ReferenceMaterialMode,
        progress: @escaping (Double) -> Void
    ) async throws -> ReferenceVideoAnalysis {
        let asset = AVURLAsset(url: videoURL)
        let durationValue = try await asset.load(.duration)
        let duration = max(0, durationValue.seconds)
        guard duration.isFinite, duration > 0 else {
            throw ReferenceVideoAnalyzerError.invalidDuration
        }

        let motionFrames = try await analyzeMotion(
            asset: asset,
            duration: duration,
            progress: progress
        )
        let audioEvents = try await analyzeAudio(
            asset: asset,
            duration: duration,
            mode: mode,
            progress: progress
        )
        let gestureEvents = inferGestures(
            frames: motionFrames,
            audioEvents: audioEvents,
            mode: mode
        )
        progress(1)

        return ReferenceVideoAnalysis(
            schemaVersion: 1,
            sourceFileName: videoURL.lastPathComponent,
            mode: mode,
            duration: duration,
            analyzedFramesPerSecond: Self.analysisFramesPerSecond,
            motionFrames: motionFrames,
            audioEvents: audioEvents,
            gestureEvents: gestureEvents,
            learnedProfile: LearnedProfileBuilder.build(from: motionFrames),
            soundRecipes: GestureSoundRecipeLibrary.all
        )
    }

    private func analyzeMotion(
        asset: AVAsset,
        duration: TimeInterval,
        progress: @escaping (Double) -> Void
    ) async throws -> [HandMotionFrame] {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ReferenceVideoAnalyzerError.missingVideoTrack
        }

        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let orientation = imageOrientation(for: preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw ReferenceVideoAnalyzerError.cannotReadVideo
        }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? ReferenceVideoAnalyzerError.cannotReadVideo
        }

        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let minimumFrameInterval = 1.0 / Self.analysisFramesPerSecond
        var lastAnalyzedTime = -Double.infinity
        var featureExtractor = HandMotionFeatureExtractor()
        var frames: [HandMotionFrame] = []

        while reader.status == .reading, let sampleBuffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            guard timestamp.isFinite, timestamp - lastAnalyzedTime >= minimumFrameInterval else {
                continue
            }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let requestHandler = VNImageRequestHandler(
                cvPixelBuffer: imageBuffer,
                orientation: orientation,
                options: [:]
            )
            try requestHandler.perform([handRequest])
            let handSample = try VisionHandPoseExtractor.sample(
                timestamp: timestamp,
                observations: handRequest.results ?? []
            )
            frames.append(featureExtractor.process(handSample))
            lastAnalyzedTime = timestamp
            progress(min(0.75, timestamp / duration * 0.75))
        }

        if reader.status == .failed {
            throw reader.error ?? ReferenceVideoAnalyzerError.cannotReadVideo
        }
        return frames
    }

    private func analyzeAudio(
        asset: AVAsset,
        duration: TimeInterval,
        mode: ReferenceMaterialMode,
        progress: @escaping (Double) -> Void
    ) async throws -> [ReferenceAudioEvent] {
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            progress(0.96)
            return []
        }

        let sampleRate = 44_100.0
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw ReferenceVideoAnalyzerError.cannotReadAudio
        }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? ReferenceVideoAnalyzerError.cannotReadAudio
        }

        var events: [ReferenceAudioEvent] = []
        var noiseFloor = 0.003
        var lastEventTime = -Double.infinity

        while reader.status == .reading, let sampleBuffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            guard
                timestamp.isFinite,
                let levels = audioLevels(in: sampleBuffer)
            else {
                continue
            }

            let threshold = max(0.012, noiseFloor * 2.35)
            if levels.rms >= threshold,
               levels.peak >= 0.04,
               timestamp - lastEventTime >= 0.065 {
                events.append(ReferenceAudioEvent(
                    timestamp: timestamp,
                    rms: levels.rms,
                    peak: levels.peak,
                    zeroCrossingRate: levels.zeroCrossingRate,
                    crestFactor: levels.crestFactor,
                    suggestedTexture: classifyAudioTexture(levels, mode: mode),
                    suggestedClipStart: max(0, timestamp - 0.08),
                    suggestedClipEnd: min(duration, timestamp + 0.38)
                ))
                lastEventTime = timestamp
            }

            noiseFloor = noiseFloor * 0.965 + min(levels.rms, threshold) * 0.035
            progress(0.75 + min(0.21, timestamp / duration * 0.21))
        }

        if reader.status == .failed {
            throw reader.error ?? ReferenceVideoAnalyzerError.cannotReadAudio
        }
        return events
    }

    private func inferGestures(
        frames: [HandMotionFrame],
        audioEvents: [ReferenceAudioEvent],
        mode: ReferenceMaterialMode
    ) -> [ReferenceGestureEvent] {
        let engine = ReferenceGestureInferenceEngine(mode: mode)
        return frames.compactMap { frame in
            guard let inferred = engine.process(frame) else {
                return nil
            }

            let closestAudio = audioEvents.enumerated().min { lhs, rhs in
                abs(lhs.element.timestamp - frame.timestamp)
                    < abs(rhs.element.timestamp - frame.timestamp)
            }
            let audioIndex = closestAudio.flatMap { item in
                abs(item.element.timestamp - frame.timestamp) <= 0.30 ? item.offset : nil
            }
            return ReferenceGestureEvent(
                timestamp: frame.timestamp,
                kind: inferred.kind,
                intensity: inferred.intensity,
                audioEventIndex: audioIndex
            )
        }
    }

    private func audioLevels(
        in sampleBuffer: CMSampleBuffer
    ) -> (rms: Double, peak: Double, zeroCrossingRate: Double, crestFactor: Double)? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer, totalLength >= MemoryLayout<Float>.size else {
            return nil
        }

        let sampleCount = totalLength / MemoryLayout<Float>.size
        let floatPointer = UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self)
        let samples = UnsafeBufferPointer(start: floatPointer, count: sampleCount)
        var sumSquares = 0.0
        var peak = 0.0
        var validCount = 0
        var zeroCrossings = 0
        var previousValue: Double?

        for sample in samples {
            let value = Double(sample)
            guard value.isFinite else {
                continue
            }
            let absoluteValue = abs(value)
            sumSquares += value * value
            peak = max(peak, absoluteValue)
            if let previousValue,
               (previousValue < 0 && value >= 0) || (previousValue >= 0 && value < 0) {
                zeroCrossings += 1
            }
            previousValue = value
            validCount += 1
        }

        guard validCount > 0 else {
            return nil
        }
        let rms = sqrt(sumSquares / Double(validCount))
        return (
            rms,
            peak,
            validCount > 1 ? Double(zeroCrossings) / Double(validCount - 1) : 0,
            rms > 0.000_001 ? peak / rms : 0
        )
    }

    private func classifyAudioTexture(
        _ levels: (
            rms: Double,
            peak: Double,
            zeroCrossingRate: Double,
            crestFactor: Double
        ),
        mode: ReferenceMaterialMode
    ) -> ReferenceAudioTexture {
        if levels.peak >= 0.62, levels.crestFactor >= 4.0 {
            return mode == .wax ? .brittleCrack : .suctionPop
        }
        if levels.zeroCrossingRate >= 0.16, levels.crestFactor >= 2.6 {
            return .bubbleCluster
        }
        if levels.rms >= 0.12, levels.crestFactor <= 3.2 {
            return mode == .wax ? .crushBody : .wetFriction
        }
        if mode == .wax {
            return .softCompression
        }
        if levels.rms > 0.015 {
            return .wetFriction
        }
        return .unknown
    }

    private func imageOrientation(
        for transform: CGAffineTransform
    ) -> CGImagePropertyOrientation {
        let epsilon = 0.01
        if abs(transform.a) < epsilon,
           transform.b > 0.9,
           transform.c < -0.9,
           abs(transform.d) < epsilon {
            return .right
        }
        if abs(transform.a) < epsilon,
           transform.b < -0.9,
           transform.c > 0.9,
           abs(transform.d) < epsilon {
            return .left
        }
        if transform.a < -0.9, transform.d < -0.9 {
            return .down
        }
        return .up
    }
}

enum ReferenceVideoAnalyzerError: LocalizedError {
    case invalidDuration
    case missingVideoTrack
    case cannotReadVideo
    case cannotReadAudio

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "The selected video has no readable duration."
        case .missingVideoTrack:
            return "The selected file does not contain a video track."
        case .cannotReadVideo:
            return "SquishMac could not decode the video frames."
        case .cannotReadAudio:
            return "SquishMac could not decode the video's audio track."
        }
    }
}
