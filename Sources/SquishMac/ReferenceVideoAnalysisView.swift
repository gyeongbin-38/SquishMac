import SwiftUI

struct ReferenceVideoAnalysisView: View {
    @ObservedObject var controller: ReferenceVideoAnalysisController
    let onChooseVideo: () -> Void
    let onExport: () -> Void
    let onRevealSavedDataset: () -> Void
    @State private var isCreatingProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            sourceControls

            if controller.isAnalyzing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: controller.progress, total: 1)
                    Text("\(Int(controller.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(controller.statusText)
                .foregroundStyle(controller.errorMessage == nil ? Color.secondary : Color.red)

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let result = controller.result {
                Divider()
                analysisSummary(result)
            }

            Spacer()

            HStack {
                Text("Analysis stays on this Mac. The exported JSON contains coordinates, features, and timestamps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Show Dataset") {
                    onRevealSavedDataset()
                }
                .disabled(controller.savedDatasetURL == nil)
                Button("Export JSON", action: onExport)
                    .disabled(controller.result == nil)
            }
        }
        .padding(22)
        .frame(width: 600, height: 520)
        .sheet(isPresented: $isCreatingProfile) {
            NewMaterialProfileView(controller: controller)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Reference Video Analyzer")
                .font(.title2.weight(.semibold))
            Text("Track fingertips, infer material gestures, and align them with sound events.")
                .foregroundStyle(.secondary)
        }
    }

    private var sourceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Material profile", selection: $controller.selectedMaterialProfileID) {
                    ForEach(controller.materialProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
                .disabled(controller.isAnalyzing)

                Button {
                    isCreatingProfile = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create a separate material profile")
                .disabled(controller.isAnalyzing)

                Button {
                    controller.removeSelectedCustomProfile()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete the selected custom profile")
                .disabled(
                    controller.isAnalyzing
                        || controller.selectedMaterialProfile.isBuiltIn
                )
            }

            HStack {
                Text(controller.selectedMaterialProfile.category.title)
                Text("Datasets: \(controller.selectedProfileDatasetCount)")
                    .monospacedDigit()
                Spacer()
                Text(controller.selectedMaterialProfile.referenceMode.title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
                Text(controller.sourceFileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose Video...", action: onChooseVideo)
                    .disabled(controller.isAnalyzing)
            }
        }
    }

    private func analysisSummary(_ result: ReferenceVideoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.materialProfile.displayName)
                .font(.headline)

            HStack(spacing: 22) {
                metric("Frames", result.motionFrames.count)
                metric("Sound events", result.audioEvents.count)
                metric("Gestures", result.gestureEvents.count)
                metric("Hands detected", result.motionFrames.filter { $0.handCount > 0 }.count)
            }

            Text(String(
                format: "Suggested response %.2fx, sound density %.2fx",
                result.learnedProfile.suggestedResponse,
                result.learnedProfile.suggestedSoundDensity
            ))
            .font(.callout)
            .foregroundStyle(.secondary)

            let groupedGestures = Dictionary(grouping: result.gestureEvents, by: \.kind)
            Text(
                ReferenceGestureKind.allCases
                    .compactMap { kind in
                        guard let count = groupedGestures[kind]?.count, count > 0 else {
                            return nil
                        }
                        return "\(kind.title): \(count)"
                    }
                    .joined(separator: "  |  ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct NewMaterialProfileView: View {
    @ObservedObject var controller: ReferenceVideoAnalysisController
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: SlimeMaterialCategory = .clear

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Material Profile")
                .font(.title2.weight(.semibold))

            TextField("Profile name", text: $name)

            Picker("Slime category", selection: $category) {
                ForEach(SlimeMaterialCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }

            Text("Each profile receives its own dataset directory, learned tuning, motion timeline, and sound mapping.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    controller.addCustomProfile(name: name, category: category)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
    }
}
