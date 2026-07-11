import Foundation

struct SoundPack: Identifiable, Hashable {
    let id: String
    let title: String
    let folderName: String
    let isCustom: Bool

    init(id: String, title: String, folderName: String, isCustom: Bool = false) {
        self.id = id
        self.title = title
        self.folderName = folderName
        self.isCustom = isCustom
    }
}

final class SoundPackManager {
    static let defaultPackID = "bubble"
    static let customPackID = "custom"
    static let supportedExtensions = Set(["wav", "mp3", "m4a", "aiff", "aif"])

    static let packs: [SoundPack] = [
        SoundPack(id: "bubble", title: "Bubble Pack", folderName: "bubble"),
        SoundPack(id: "slime", title: "Slime Pack", folderName: "slime"),
        SoundPack(id: "squishy", title: "Squishy Pack", folderName: "squishy"),
        SoundPack(id: "pop", title: "Pop Pack", folderName: "pop"),
        SoundPack(id: "wax", title: "Wax Squish Pack", folderName: "wax")
    ]

    static let customPack = SoundPack(
        id: customPackID,
        title: "Custom Folder",
        folderName: "",
        isCustom: true
    )

    func availablePacks(includeCustom: Bool = true) -> [SoundPack] {
        includeCustom ? Self.packs + [Self.customPack] : Self.packs
    }

    func pack(for id: String) -> SoundPack {
        if id == Self.customPackID {
            return Self.customPack
        }

        return Self.packs.first { $0.id == id } ?? Self.packs[0]
    }

    func soundURLs(for packID: String, customDirectoryPath: String?) -> [URL] {
        if packID == Self.customPackID {
            guard let customDirectoryPath else {
                return []
            }

            return urls(inDirectory: URL(fileURLWithPath: customDirectoryPath), recursive: true)
        }

        let selectedPack = pack(for: packID)
        let selectedURLs = urls(in: selectedPack.folderName)

        if selectedURLs.isEmpty {
            return Self.packs.flatMap { urls(in: $0.folderName) }
        }

        return selectedURLs
    }

    func soundCount(for packID: String, customDirectoryPath: String?) -> Int {
        soundURLs(for: packID, customDirectoryPath: customDirectoryPath).count
    }

    private func urls(in folderName: String) -> [URL] {
        guard let resourceURL = Bundle.module.resourceURL else {
            return []
        }

        let directory = resourceURL
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)

        return urls(inDirectory: directory, recursive: false)
    }

    private func urls(inDirectory directory: URL, recursive: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]

        if recursive {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            return enumerator
                .compactMap { $0 as? URL }
                .filter { isPlayableSoundFile($0) }
                .sorted { $0.path < $1.path }
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { isPlayableSoundFile($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func isPlayableSoundFile(_ url: URL) -> Bool {
        guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return false
        }

        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }
}
