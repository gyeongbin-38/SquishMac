import Combine
import Foundation

@MainActor
final class ReferenceVideoAnalysisController: ObservableObject {
    @Published var mode: ReferenceMaterialMode = .slime
    @Published private(set) var sourceFileName = "No video selected"
    @Published private(set) var progress = 0.0
    @Published private(set) var isAnalyzing = false
    @Published private(set) var statusText = "Choose a reference video to begin."
    @Published private(set) var result: ReferenceVideoAnalysis?
    @Published private(set) var errorMessage: String?

    private var analysisTask: Task<Void, Never>?
    private var analysisID = UUID()

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
        let selectedMode = mode

        analysisTask = Task(priority: .userInitiated) { [weak self] in
            do {
                let analysis = try await ReferenceVideoAnalyzer().analyze(
                    videoURL: videoURL,
                    mode: selectedMode
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
                statusText = "Analysis complete. Export the timeline as JSON."
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
}

enum ReferenceVideoAnalysisControllerError: LocalizedError {
    case noResult

    var errorDescription: String? {
        "There is no completed video analysis to export."
    }
}
