import Combine
import Foundation

@MainActor
final class ReferenceVideoAnalysisController: ObservableObject {
    @Published private(set) var materialProfiles: [SlimeMaterialProfile]
    @Published var selectedMaterialProfileID: String {
        didSet {
            defaults.set(selectedMaterialProfileID, forKey: Keys.selectedProfileID)
        }
    }
    @Published private(set) var sourceFileName = "No video selected"
    @Published private(set) var progress = 0.0
    @Published private(set) var isAnalyzing = false
    @Published private(set) var statusText = "Choose a reference video to begin."
    @Published private(set) var result: ReferenceVideoAnalysis?
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedDatasetURL: URL?

    private let defaults: UserDefaults
    private let datasetLibrary: ReferenceDatasetLibrary
    private var analysisTask: Task<Void, Never>?
    private var analysisID = UUID()

    init(
        defaults: UserDefaults = .standard,
        datasetLibrary: ReferenceDatasetLibrary = ReferenceDatasetLibrary()
    ) {
        self.defaults = defaults
        self.datasetLibrary = datasetLibrary

        let customProfiles: [SlimeMaterialProfile]
        if let data = defaults.data(forKey: Keys.customProfiles),
           let decoded = try? JSONDecoder().decode([SlimeMaterialProfile].self, from: data) {
            customProfiles = decoded.filter { !$0.isBuiltIn }
        } else {
            customProfiles = []
        }
        self.materialProfiles = SlimeMaterialProfile.builtIn + customProfiles

        let storedID = defaults.string(forKey: Keys.selectedProfileID)
        self.selectedMaterialProfileID = (
            SlimeMaterialProfile.builtIn + customProfiles
        ).contains { $0.id == storedID }
            ? storedID ?? SlimeMaterialProfile.builtIn[0].id
            : SlimeMaterialProfile.builtIn[0].id
    }

    var selectedMaterialProfile: SlimeMaterialProfile {
        materialProfiles.first { $0.id == selectedMaterialProfileID }
            ?? SlimeMaterialProfile.builtIn[0]
    }

    var selectedProfileDatasetCount: Int {
        datasetLibrary.datasetCount(for: selectedMaterialProfileID)
    }

    func analyze(videoURL: URL) {
        analysisTask?.cancel()

        let currentAnalysisID = UUID()
        analysisID = currentAnalysisID
        sourceFileName = videoURL.lastPathComponent
        progress = 0
        isAnalyzing = true
        statusText = "Tracking fingertips and reading the audio timeline..."
        result = nil
        errorMessage = nil
        savedDatasetURL = nil
        let selectedProfile = selectedMaterialProfile

        analysisTask = Task(priority: .userInitiated) { [weak self] in
            do {
                let analysis = try await ReferenceVideoAnalyzer().analyze(
                    videoURL: videoURL,
                    materialProfile: selectedProfile
                ) { progress in
                    Task { @MainActor [weak self] in
                        guard self?.analysisID == currentAnalysisID else {
                            return
                        }
                        self?.progress = progress
                    }
                }
                try Task.checkCancellation()

                guard let self, self.analysisID == currentAnalysisID else {
                    return
                }
                result = analysis
                progress = 1
                isAnalyzing = false
                do {
                    savedDatasetURL = try datasetLibrary.save(analysis)
                    statusText = "Analysis complete and saved to the material dataset library."
                } catch {
                    errorMessage = "Analysis completed, but the dataset could not be saved: \(error.localizedDescription)"
                    statusText = "Analysis complete. Export the timeline as JSON."
                }
            } catch is CancellationError {
                guard let self, self.analysisID == currentAnalysisID else {
                    return
                }
                isAnalyzing = false
                statusText = "Analysis cancelled."
            } catch {
                guard let self, self.analysisID == currentAnalysisID else {
                    return
                }
                isAnalyzing = false
                errorMessage = error.localizedDescription
                statusText = "The reference video could not be analyzed."
            }
        }
    }

    func cancel() {
        analysisID = UUID()
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
        statusText = "Analysis cancelled."
    }

    func encodedResult() throws -> Data {
        guard let result else {
            throw ReferenceVideoAnalysisControllerError.noResult
        }
        return try result.encodedJSON()
    }

    func addCustomProfile(name: String, category: SlimeMaterialCategory) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        let profile = SlimeMaterialProfile(
            id: "\(slug(trimmedName))-\(UUID().uuidString.prefix(8).lowercased())",
            displayName: trimmedName,
            category: category,
            outerTexture: category == .waxShell ? "brittle wax shell" : "",
            coreTexture: category.title,
            notes: "",
            isBuiltIn: false
        )
        materialProfiles.append(profile)
        selectedMaterialProfileID = profile.id
        persistCustomProfiles()
    }

    func removeSelectedCustomProfile() {
        guard let profile = materialProfiles.first(
            where: { $0.id == selectedMaterialProfileID }
        ), !profile.isBuiltIn else {
            return
        }
        materialProfiles.removeAll { $0.id == profile.id }
        selectedMaterialProfileID = SlimeMaterialProfile.builtIn[0].id
        persistCustomProfiles()
    }

    private func persistCustomProfiles() {
        let customProfiles = materialProfiles.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customProfiles) {
            defaults.set(data, forKey: Keys.customProfiles)
        }
    }

    private func slug(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = CharacterSet.alphanumerics
        let characters = lowered.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let result = String(characters)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "material" : result
    }
}

enum ReferenceVideoAnalysisControllerError: LocalizedError {
    case noResult

    var errorDescription: String? {
        "There is no completed video analysis to export."
    }
}

private enum Keys {
    static let selectedProfileID = "referenceAnalysis.selectedMaterialProfileID"
    static let customProfiles = "referenceAnalysis.customMaterialProfiles"
}
