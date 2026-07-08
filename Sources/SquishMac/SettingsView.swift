import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var motionDetector: MotionDetector

    let soundPackManager: SoundPackManager
    let onTestSound: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SquishMac")
                        .font(.title2.weight(.semibold))
                    Text("Menu bar squish sound toy")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("On", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
            }

            Divider()

            Picker("Sound Pack", selection: $settings.selectedSoundPackID) {
                ForEach(soundPackManager.availablePacks) { pack in
                    Text(pack.title).tag(pack.id)
                }
            }
            .pickerStyle(.menu)

            settingSlider(
                title: "Sensitivity",
                value: $settings.sensitivity,
                range: SettingsStore.sensitivityRange,
                format: "%.2f g"
            )

            settingSlider(
                title: "Cooldown",
                value: $settings.cooldown,
                range: SettingsStore.cooldownRange,
                format: "%.2f s"
            )

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Motion source")
                        .foregroundStyle(.secondary)
                    Text(motionDetector.activeSourceName)
                }

                GridRow {
                    Text("Detector")
                        .foregroundStyle(.secondary)
                    Text(motionDetector.state.rawValue)
                }

                GridRow {
                    Text("Last impact")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.3f g", motionDetector.lastStrength))
                }

                GridRow {
                    Text("Played today")
                        .foregroundStyle(.secondary)
                    Text("\(settings.todaysCount)")
                }
            }

            HStack {
                Button("Test Sound", action: onTestSound)
                Button("Reset Today") {
                    settings.resetTodayCount()
                }

                Spacer()
            }
        }
        .padding(22)
        .frame(width: 420)
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }
}
