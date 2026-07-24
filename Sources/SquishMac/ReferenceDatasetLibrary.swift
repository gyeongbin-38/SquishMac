import Foundation

struct ReferenceDatasetLibrary {
    let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
            return
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        self.rootURL = applicationSupport
            .appendingPathComponent("SquishMac", isDirectory: true)
            .appendingPathComponent("ReferenceDatasets", isDirectory: true)
    }

    func save(_ analysis: ReferenceVideoAnalysis) throws -> URL {
        let profileDirectory = rootURL.appendingPathComponent(
            safePathComponent(analysis.materialProfile.id),
            isDirectory: true
        )
        let datasetDirectory = profileDirectory.appendingPathComponent(
            safePathComponent(analysis.datasetID),
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: datasetDirectory,
            withIntermediateDirectories: true
        )

        let analysisURL = datasetDirectory.appendingPathComponent("analysis.json")
        try analysis.encodedJSON().write(to: analysisURL, options: .atomic)
        return analysisURL
    }

    func load(from analysisURL: URL) throws -> ReferenceVideoAnalysis {
        let data = try Data(contentsOf: analysisURL)
        return try ReferenceVideoAnalysis.decoder().decode(
            ReferenceVideoAnalysis.self,
            from: data
        )
    }

    func datasetCount(for profileID: String) -> Int {
        let profileDirectory = rootURL.appendingPathComponent(
            safePathComponent(profileID),
            isDirectory: true
        )
        let values = try? profileDirectory.resourceValues(forKeys: [.isDirectoryKey])
        guard values?.isDirectory == true else {
            return 0
        }

        let entries = try? FileManager.default.contentsOfDirectory(
            at: profileDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return entries?.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.count ?? 0
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let result = String(components)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "dataset" : result
    }
}
