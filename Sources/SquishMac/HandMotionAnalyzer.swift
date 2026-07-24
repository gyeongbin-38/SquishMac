import Foundation

struct HandMotionFeatureExtractor {
    private var previousPoints: [String: NormalizedPosePoint] = [:]

    mutating func process(_ sample: HandPoseSample) -> HandMotionFrame {
        let allPoints = flattenedPoints(in: sample)
        let fingertips = allPoints.filter { $0.joint.isFingertip }
        let wrists = allPoints.filter { $0.joint == .wrist }
        let centroid = centroid(of: fingertips.map(\.point))
        let movement = averageMovement(of: fingertips)
        let spread = maximumDistance(in: fingertips.map(\.point))
        let openness = averageOpenness(fingertips: fingertips, wrists: wrists)
        let pinch = maximumPinch(in: sample.hands)
        let compression = ((0.30 - openness) / 0.20).clamped(to: 0.0...1.0)
        let pressureEstimate = max(compression, pinch * 0.88).clamped(to: 0.0...1.0)

        previousPoints = Dictionary(
            uniqueKeysWithValues: allPoints.map { ($0.id, $0.point) }
        )

        return HandMotionFrame(
            timestamp: sample.timestamp,
            handCount: sample.hands.count,
            fingertipCount: fingertips.count,
            centroidX: centroid.x,
            centroidY: centroid.y,
            movement: movement,
            spread: spread,
            openness: openness,
            pinch: pinch,
            pressureEstimate: pressureEstimate,
            hands: sample.hands
        )
    }

    mutating func reset() {
        previousPoints.removeAll()
    }

    private func flattenedPoints(
        in sample: HandPoseSample
    ) -> [(id: String, handID: Int, joint: HandJointName, point: NormalizedPosePoint)] {
        sample.hands.flatMap { hand in
            hand.joints.map { joint, point in
                ("\(hand.id)-\(joint.rawValue)", hand.id, joint, point)
            }
        }
    }

    private func centroid(of points: [NormalizedPosePoint]) -> (x: Double, y: Double) {
        guard !points.isEmpty else {
            return (0, 0)
        }

        return (
            points.reduce(0) { $0 + $1.x } / Double(points.count),
            points.reduce(0) { $0 + $1.y } / Double(points.count)
        )
    }

    private func averageMovement(
        of points: [(id: String, handID: Int, joint: HandJointName, point: NormalizedPosePoint)]
    ) -> Double {
        let distances = points.compactMap { item -> Double? in
            guard let previousPoint = previousPoints[item.id] else {
                return nil
            }
            return distance(item.point, previousPoint)
        }

        guard !distances.isEmpty else {
            return 0
        }

        return (distances.reduce(0, +) / Double(distances.count) * 8.0)
            .clamped(to: 0.0...1.0)
    }

    private func maximumDistance(in points: [NormalizedPosePoint]) -> Double {
        guard points.count >= 2 else {
            return 0
        }

        var result = 0.0
        for leftIndex in 0..<points.count {
            for rightIndex in (leftIndex + 1)..<points.count {
                result = max(result, distance(points[leftIndex], points[rightIndex]))
            }
        }
        return result.clamped(to: 0.0...1.0)
    }

    private func averageOpenness(
        fingertips: [(id: String, handID: Int, joint: HandJointName, point: NormalizedPosePoint)],
        wrists: [(id: String, handID: Int, joint: HandJointName, point: NormalizedPosePoint)]
    ) -> Double {
        let wristByHand = Dictionary(
            uniqueKeysWithValues: wrists.map { ($0.handID, $0.point) }
        )
        let distances = fingertips.compactMap { fingertip -> Double? in
            guard let wrist = wristByHand[fingertip.handID] else {
                return nil
            }
            return distance(fingertip.point, wrist)
        }

        guard !distances.isEmpty else {
            return 0
        }
        return (distances.reduce(0, +) / Double(distances.count)).clamped(to: 0.0...1.0)
    }

    private func maximumPinch(in hands: [DetectedHandPose]) -> Double {
        hands.reduce(0) { result, hand in
            guard
                let thumb = hand.joints[.thumbTip],
                let index = hand.joints[.indexTip]
            else {
                return result
            }

            let separation = distance(thumb, index)
            let pinch = (1.0 - ((separation - 0.015) / 0.16)).clamped(to: 0.0...1.0)
            return max(result, pinch)
        }
    }

    private func distance(_ lhs: NormalizedPosePoint, _ rhs: NormalizedPosePoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt(dx * dx + dy * dy)
    }
}

final class ReferenceGestureInferenceEngine {
    private enum WaxStage: Int {
        case idle
        case press
        case crack
        case crush
    }

    private let mode: ReferenceMaterialMode
    private var previousFrame: HandMotionFrame?
    private var lastTriggerTimes: [ReferenceGestureKind: TimeInterval] = [:]
    private var waxStage: WaxStage = .idle

    init(mode: ReferenceMaterialMode) {
        self.mode = mode
    }

    func process(_ frame: HandMotionFrame) -> (kind: ReferenceGestureKind, intensity: Double)? {
        defer {
            previousFrame = frame
        }

        switch mode {
        case .slime:
            return processSlime(frame)
        case .wax:
            return processWax(frame)
        }
    }

    private func processSlime(
        _ frame: HandMotionFrame
    ) -> (kind: ReferenceGestureKind, intensity: Double)? {
        if let previousFrame,
           previousFrame.fingertipCount >= 3,
           frame.fingertipCount < 2 {
            return trigger(
                .slimeRelease,
                intensity: max(0.35, previousFrame.pressureEstimate),
                timestamp: frame.timestamp,
                cooldown: 0.12
            )
        }

        guard frame.fingertipCount >= 3 else {
            return nil
        }

        let intensity = (
            Double(min(frame.fingertipCount, 10)) / 10.0 * 0.25
            + frame.movement * 0.35
            + frame.pressureEstimate * 0.30
            + frame.spread * 0.10
        ).clamped(to: 0.0...1.0)

        let kind: ReferenceGestureKind
        if frame.movement >= 0.24 && frame.spread >= 0.34 {
            kind = .slimeStretch
        } else if frame.movement >= 0.08 {
            kind = .slimeKnead
        } else if frame.pressureEstimate >= 0.28 {
            kind = .slimePress
        } else {
            return nil
        }

        return trigger(
            kind,
            intensity: intensity,
            timestamp: frame.timestamp,
            cooldown: kind == .slimePress ? 0.28 : 0.16
        )
    }

    private func processWax(
        _ frame: HandMotionFrame
    ) -> (kind: ReferenceGestureKind, intensity: Double)? {
        guard frame.handCount >= 1, frame.fingertipCount >= 2 else {
            if frame.fingertipCount == 0 {
                waxStage = .idle
            }
            return nil
        }

        let pressure = max(
            frame.pressureEstimate,
            min(1, frame.movement * 0.45 + frame.pinch * 0.65)
        )
        let nextStage: WaxStage
        if pressure >= 0.78 {
            nextStage = .crush
        } else if pressure >= 0.55 {
            nextStage = .crack
        } else if pressure >= 0.25 {
            nextStage = .press
        } else {
            return nil
        }

        guard nextStage.rawValue > waxStage.rawValue else {
            return nil
        }
        waxStage = nextStage

        let kind: ReferenceGestureKind
        switch nextStage {
        case .idle:
            return nil
        case .press:
            kind = .waxPress
        case .crack:
            kind = .waxCrack
        case .crush:
            kind = .waxCrush
        }

        return trigger(kind, intensity: pressure, timestamp: frame.timestamp, cooldown: 0.12)
    }

    private func trigger(
        _ kind: ReferenceGestureKind,
        intensity: Double,
        timestamp: TimeInterval,
        cooldown: TimeInterval
    ) -> (kind: ReferenceGestureKind, intensity: Double)? {
        let lastTime = lastTriggerTimes[kind] ?? -Double.infinity
        guard timestamp - lastTime >= cooldown else {
            return nil
        }
        lastTriggerTimes[kind] = timestamp
        return (kind, intensity.clamped(to: 0.0...1.0))
    }
}

enum LearnedProfileBuilder {
    static func build(from frames: [HandMotionFrame]) -> LearnedGestureProfile {
        let movement = frames.map(\.movement)
        let pressure = frames.map(\.pressureEstimate)
        let spread = frames.map(\.spread)
        let movementMedian = percentile(movement, 0.5)
        let movementHigh = percentile(movement, 0.9)
        let pressureMedian = percentile(pressure, 0.5)
        let pressureHigh = percentile(pressure, 0.9)

        return LearnedGestureProfile(
            movementMedian: movementMedian,
            movementHigh: movementHigh,
            pressureMedian: pressureMedian,
            pressureHigh: pressureHigh,
            spreadMedian: percentile(spread, 0.5),
            suggestedResponse: (1.15 - pressureMedian * 0.35).clamped(to: 0.65...1.55),
            suggestedSoundDensity: (0.8 + movementHigh * 0.65).clamped(to: 0.65...1.65)
        )
    }

    private static func percentile(_ values: [Double], _ percentile: Double) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        let sortedValues = values.sorted()
        let index = Int(
            (Double(sortedValues.count - 1) * percentile.clamped(to: 0.0...1.0)).rounded()
        )
        return sortedValues[index]
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
