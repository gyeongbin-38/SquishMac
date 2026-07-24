import Foundation

enum GestureSoundRecipeLibrary {
    static let all: [GestureSoundRecipe] = ReferenceGestureKind.allCases.map(recipe)

    static func recipe(for gesture: ReferenceGestureKind) -> GestureSoundRecipe {
        switch gesture {
        case .slimePress:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("wet-contact", "slime", 1.0, 0.20...0.58, 0.76...1.02, 0...8, false),
                layer("micro-bubbles", "bubble", 0.28, 0.08...0.26, 0.90...1.18, 5...45, true)
            ])
        case .slimeKnead:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("wet-friction", "slime", 1.0, 0.28...0.78, 0.78...1.14, 0...10, false),
                layer("dense-fold", "squishy", 0.36, 0.10...0.38, 0.68...0.96, 12...70, true),
                layer("micro-bubbles", "bubble", 0.22, 0.06...0.22, 0.94...1.24, 20...95, true)
            ])
        case .slimeStretch:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("elastic-stretch", "slime", 1.0, 0.24...0.72, 0.58...0.88, 0...12, false),
                layer("suction-thread", "squishy", 0.42, 0.08...0.30, 0.62...0.90, 25...110, true)
            ])
        case .slimeRelease:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("suction-release", "pop", 1.0, 0.26...0.82, 0.86...1.18, 0...10, false),
                layer("air-pocket", "bubble", 0.48, 0.08...0.32, 0.94...1.28, 8...80, true)
            ])
        case .waxPress:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("soft-compression", "squishy", 1.0, 0.18...0.56, 0.66...0.96, 0...10, false),
                layer("surface-creak", "wax", 0.24, 0.05...0.20, 0.72...0.98, 18...75, true)
            ])
        case .waxCrack:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("brittle-crack", "wax", 1.0, 0.35...0.82, 0.86...1.20, 0...8, false),
                layer("micro-snap", "pop", 0.46, 0.10...0.34, 1.02...1.34, 3...45, true)
            ])
        case .waxCrush:
            return GestureSoundRecipe(gesture: gesture, layers: [
                layer("shell-break", "wax", 1.0, 0.52...1.0, 0.74...1.28, 0...8, false),
                layer("crush-body", "squishy", 0.62, 0.16...0.52, 0.62...0.94, 8...65, true),
                layer("crush-debris", "bubble", 0.44, 0.10...0.36, 1.00...1.36, 15...105, true)
            ])
        }
    }

    static func recipe(for soundKind: TrackpadSoundKind) -> GestureSoundRecipe {
        switch soundKind {
        case .slimeKnead:
            return recipe(for: ReferenceGestureKind.slimeKnead)
        case .slimeStretch:
            return recipe(for: ReferenceGestureKind.slimeStretch)
        case .slimeRelease:
            return recipe(for: ReferenceGestureKind.slimeRelease)
        case .waxPress:
            return recipe(for: ReferenceGestureKind.waxPress)
        case .waxCrack:
            return recipe(for: ReferenceGestureKind.waxCrack)
        case .waxCrush:
            return recipe(for: ReferenceGestureKind.waxCrush)
        }
    }

    private static func layer(
        _ role: String,
        _ packID: String,
        _ probability: Double,
        _ volume: ClosedRange<Double>,
        _ rate: ClosedRange<Double>,
        _ delay: ClosedRange<Double>,
        _ canSynthesize: Bool
    ) -> SoundLayerRecipe {
        SoundLayerRecipe(
            role: role,
            sourcePackID: packID,
            probability: probability,
            volume: SoundParameterRange(minimum: volume.lowerBound, maximum: volume.upperBound),
            playbackRate: SoundParameterRange(minimum: rate.lowerBound, maximum: rate.upperBound),
            delayMilliseconds: SoundParameterRange(minimum: delay.lowerBound, maximum: delay.upperBound),
            canBeSynthesizedWhenMissing: canSynthesize
        )
    }
}
