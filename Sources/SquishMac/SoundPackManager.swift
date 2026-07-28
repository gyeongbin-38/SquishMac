import Foundation

struct SoundPack: Identifiable, Hashable {
    let id: String
    let title: String
    let folderName: String
    let isCustom: Bool
    let isUserSelectable: Bool

    init(
        id: String,
        title: String,
        folderName: String,
        isCustom: Bool = false,
        isUserSelectable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.folderName = folderName
        self.isCustom = isCustom
        self.isUserSelectable = isUserSelectable
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
        SoundPack(id: "wax", title: "Wax Squish Pack", folderName: "wax"),
        SoundPack(
            id: "doctor-putty-failure",
            title: "Doctor Putty Failure",
            folderName: "doctor-putty-failure",
            isUserSelectable: false
        ),
        SoundPack(
            id: "clear-video-3-knead",
            title: "Clear Slime 3 Knead",
            folderName: "clear-video-3-knead",
            isUserSelectable: false
        ),
        SoundPack(
            id: "clear-video-3-stretch",
            title: "Clear Slime 3 Stretch",
            folderName: "clear-video-3-stretch",
            isUserSelectable: false
        ),
        SoundPack(
            id: "pastel-wax-video-4-press",
            title: "Pastel Wax 4 Press",
            folderName: "pastel-wax-video-4-press",
            isUserSelectable: false
        ),
        SoundPack(
            id: "pastel-wax-video-4-crack",
            title: "Pastel Wax 4 Crack",
            folderName: "pastel-wax-video-4-crack",
            isUserSelectable: false
        ),
        SoundPack(
            id: "pastel-wax-video-4-crush",
            title: "Pastel Wax 4 Crush",
            folderName: "pastel-wax-video-4-crush",
            isUserSelectable: false
        ),
        SoundPack(
            id: "white-putty-video-5-knead",
            title: "White Putty 5 Knead",
            folderName: "white-putty-video-5-knead",
            isUserSelectable: false
        ),
        SoundPack(
            id: "white-putty-video-5-stretch",
            title: "White Putty 5 Stretch",
            folderName: "white-putty-video-5-stretch",
            isUserSelectable: false
        ),
        SoundPack(
            id: "aerated-clear-video-6-knead",
            title: "Aerated Clear 6 Knead",
            folderName: "aerated-clear-video-6-knead",
            isUserSelectable: false
        ),
        SoundPack(
            id: "aerated-clear-video-6-stretch",
            title: "Aerated Clear 6 Stretch",
            folderName: "aerated-clear-video-6-stretch",
            isUserSelectable: false
        )
    ]

    static let customPack = SoundPack(
        id: customPackID,
        title: "Custom Folder",
        folderName: "",
        isCustom: true
    )

    func availablePacks(includeCustom: Bool = true) -> [SoundPack] {
        let selectablePacks = Self.packs.filter(\.isUserSelectable)
        return includeCustom ? selectablePacks + [Self.customPack] : selectablePacks
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
        return urls(in: selectedPack.folderName)
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

        let nestedURLs = urls(inDirectory: directory, recursive: false)
        if !nestedURLs.isEmpty {
            return nestedURLs
        }

        // SwiftPM may flatten processed resource directories in the generated bundle.
        return urls(inDirectory: resourceURL, recursive: false)
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("\(folderName)-") }
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
