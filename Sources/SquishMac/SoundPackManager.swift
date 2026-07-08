import Foundation

struct SoundPack: Identifiable, Hashable {
    let id: String
    let title: String
    let folderName: String
}

final class SoundPackManager {
    static let packs: [SoundPack] = [
        SoundPack(id: "bubble", title: "Bubble Pack", folderName: "bubble"),
        SoundPack(id: "slime", title: "Slime Pack", folderName: "slime"),
        SoundPack(id: "squishy", title: "Squishy Pack", folderName: "squishy"),
        SoundPack(id: "pop", title: "Pop Pack", folderName: "pop")
    ]

    var availablePacks: [SoundPack] {
        Self.packs
    }

    func pack(for id: String) -> SoundPack {
        Self.packs.first { $0.id == id } ?? Self.packs[0]
    }

    func soundURLs(for packID: String) -> [URL] {
        let selectedPack = pack(for: packID)
        let selectedURLs = urls(in: selectedPack.folderName)

        if selectedURLs.isEmpty {
            return Self.packs.flatMap { urls(in: $0.folderName) }
        }

        return selectedURLs
    }

    private func urls(in folderName: String) -> [URL] {
        guard let resourceURL = Bundle.module.resourceURL else {
            return []
        }

        let directory = resourceURL
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)

        let extensions = Set(["wav", "mp3", "m4a", "aiff", "aif"])
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
