import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var motionDetector: MotionDetector
    @ObservedObject var soundPlayer: SoundPlayer

    let soundPackManager: SoundPackManager
    let onTestSound: () -> Void
    let onChooseCustomSoundFolder: () -> Void
    let onClearCustomSoundFolder: () -> Void
    let onRevealCustomSoundFolder: () -> Void
    let onSetLaunchAtLogin: (Bool) -> Void
    let onRecalibrateMotion: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Divider()

                generalSettings

                Divider()

                trackpadSettings

                Divider()

                soundSettings

                Divider()

                detectionSettings

                Divider()

                motionMonitor

                Divider()

                footerActions
            }
            .padding(22)
        }
        .frame(width: 500, height: 700)
    }

    private var header: some View {
        HStack(alignment: .center) {
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
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("General")

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { settings.launchAtLoginStatus == .enabled },
                    set: { onSetLaunchAtLogin($0) }
                )
            )
            .disabled(settings.launchAtLoginStatus == .unavailable)

            HStack {
                Text("Login status")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(settings.launchAtLoginStatus.rawValue)
                    .monospacedDigit()
            }

            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var soundSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Sound")

            settingSlider(
                title: "Master Volume",
                value: $settings.masterVolume,
                range: SettingsStore.masterVolumeRange,
                format: "%.0f%%",
                displayMultiplier: 100
            )

            Picker("Impact Sound Pack", selection: $settings.selectedSoundPackID) {
                ForEach(soundPackManager.availablePacks()) { pack in
                    Text(pack.title)
                        .tag(pack.id)
                        .disabled(pack.isCustom && settings.customSoundDirectoryPath == nil)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom folder")
                    .foregroundStyle(.secondary)

                Text(settings.customSoundDirectoryDisplayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Button("Choose Folder", action: onChooseCustomSoundFolder)

                Button("Reveal", action: onRevealCustomSoundFolder)
                    .disabled(settings.customSoundDirectoryPath == nil)

                Button("Clear", action: onClearCustomSoundFolder)
                    .disabled(settings.customSoundDirectoryPath == nil)

                Spacer()
            }

            if let lastPlayedFileName = soundPlayer.lastPlayedFileName {
                HStack {
                    Text("Last played")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastPlayedFileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            if let error = soundPlayer.lastPlaybackError {
                HStack(alignment: .top) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Dismiss") {
                        soundPlayer.clearPlaybackError()
                    }
                }
            }
        }
    }

    private var trackpadSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trackpad")

            Picker("Default Mode", selection: $settings.trackpadMode) {
                ForEach(TrackpadMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Wax crack and crush haptics", isOn: $settings.isHapticFeedbackEnabled)

            settingSlider(
                title: "Touch Response",
                value: $settings.trackpadResponse,
                range: SettingsStore.trackpadResponseRange,
                format: "%.2fx"
            )

            settingSlider(
                title: "Sound Density",
                value: $settings.trackpadSoundDensity,
                range: SettingsStore.soundDensityRange,
                format: "%.2fx"
            )
        }
    }

    private var detectionSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Detection")

            Toggle("Motion impact sounds", isOn: $settings.isImpactDetectionEnabled)

            settingSlider(
                title: "Sensitivity",
                value: $settings.sensitivity,
                range: SettingsStore.sensitivityRange,
                format: "%.2f g"
            )
            .disabled(!settings.isImpactDetectionEnabled)

            settingSlider(
                title: "Cooldown",
                value: $settings.cooldown,
                range: SettingsStore.cooldownRange,
                format: "%.2f s"
            )
            .disabled(!settings.isImpactDetectionEnabled)
        }
    }

    private var motionMonitor: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Motion Monitor")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Live motion")
                    Spacer()
                    Text(String(format: "%.3f g", motionDetector.currentStrength))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ProgressView(
                    value: min(motionDetector.currentStrength, meterMaximum),
                    total: meterMaximum
                )

                Text("Triggers at \(String(format: "%.2f g", settings.sensitivity))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                        .monospacedDigit()
                }

                GridRow {
                    Text("Last impact time")
                        .foregroundStyle(.secondary)
                    Text(formattedTime(motionDetector.lastImpactDate))
                }

                GridRow {
                    Text("Played today")
                        .foregroundStyle(.secondary)
                    Text("\(settings.todaysCount)")
                        .monospacedDigit()
                }
            }

            Button("Recalibrate Motion", action: onRecalibrateMotion)
                .disabled(!settings.isEnabled || !settings.isImpactDetectionEnabled)
        }
    }

    private var footerActions: some View {
        HStack {
            Button("Test Sound", action: onTestSound)
            Button("Reset Today") {
                settings.resetTodayCount()
            }

            Spacer()
        }
    }

    private var meterMaximum: Double {
        max(settings.sensitivity * 3.0, 0.5)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        displayMultiplier: Double = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue * displayMultiplier))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let date else {
            return "None"
        }

        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
}
