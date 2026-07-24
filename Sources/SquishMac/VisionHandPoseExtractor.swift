import Foundation
import Vision

enum VisionHandPoseExtractor {
    static func sample(
        timestamp: TimeInterval,
        observations: [VNHumanHandPoseObservation],
        minimumConfidence: Float = 0.25
    ) throws -> HandPoseSample {
        let mappedHands = try observations.map { observation -> [HandJointName: NormalizedPosePoint] in
            var joints: [HandJointName: NormalizedPosePoint] = [:]
            for jointName in HandJointName.allCases {
                let point = try observation.recognizedPoint(visionJoint(for: jointName))
                guard point.confidence >= minimumConfidence else {
                    continue
                }
                joints[jointName] = NormalizedPosePoint(
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    confidence: Double(point.confidence)
                )
            }
            return joints
        }
        .filter { !$0.isEmpty }
        .sorted { lhs, rhs in
            (lhs[.wrist]?.x ?? lhs[.indexTip]?.x ?? 0)
                < (rhs[.wrist]?.x ?? rhs[.indexTip]?.x ?? 0)
        }

        let hands = mappedHands.enumerated().map { index, joints in
            DetectedHandPose(id: index, joints: joints)
        }
        return HandPoseSample(timestamp: timestamp, hands: hands)
    }

    private static func visionJoint(
        for joint: HandJointName
    ) -> VNHumanHandPoseObservation.JointName {
        switch joint {
        case .wrist:
            return .wrist
        case .thumbTip:
            return .thumbTip
        case .indexTip:
            return .indexTip
        case .middleTip:
            return .middleTip
        case .ringTip:
            return .ringTip
        case .littleTip:
            return .littleTip
        }
    }
}
