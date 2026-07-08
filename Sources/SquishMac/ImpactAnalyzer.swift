import Foundation

struct ImpactAnalysisResult {
    let currentStrength: Double
    let impactStrength: Double?
}

final class ImpactAnalyzer {
    private var baseline: AccelerationVector?
    private var lastSample: AccelerationVector?
    private var lastTriggerTime = -Double.infinity
    private let baselineBlendFactor: Double

    init(baselineBlendFactor: Double = 0.06) {
        self.baselineBlendFactor = baselineBlendFactor.clamped(to: 0.0...1.0)
    }

    func reset() {
        baseline = nil
        lastSample = nil
        lastTriggerTime = -Double.infinity
    }

    func process(
        sample: AccelerationVector,
        sensitivity: Double,
        cooldown: TimeInterval,
        timestamp: TimeInterval
    ) -> ImpactAnalysisResult {
        guard let currentBaseline = baseline else {
            baseline = sample
            lastSample = sample
            return ImpactAnalysisResult(currentStrength: 0, impactStrength: nil)
        }

        let highPassStrength = sample.distance(to: currentBaseline)
        let jerkStrength = lastSample.map { sample.distance(to: $0) } ?? 0
        let strength = max(highPassStrength, jerkStrength)

        baseline = currentBaseline.mixed(with: sample, factor: baselineBlendFactor)
        lastSample = sample

        let threshold = max(sensitivity, 0.01)
        let safeCooldown = max(cooldown, 0)

        guard strength >= threshold else {
            return ImpactAnalysisResult(currentStrength: strength, impactStrength: nil)
        }

        guard timestamp - lastTriggerTime >= safeCooldown else {
            return ImpactAnalysisResult(currentStrength: strength, impactStrength: nil)
        }

        lastTriggerTime = timestamp
        return ImpactAnalysisResult(currentStrength: strength, impactStrength: strength)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
