import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let soundPackManager = SoundPackManager()
    private lazy var soundPlayer = SoundPlayer(packManager: soundPackManager)
    private lazy var motionDetector = MotionDetector(settings: settings)
    private lazy var trackpadState = TrackpadInteractionState(mode: settings.trackpadMode)

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var trackpadWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        refreshLaunchAtLoginStatus()
        setupMenuBar()
        bindSettings()

        motionDetector.onImpact = { [weak self] impact in
            self?.handleImpact(impact)
        }

    }

    private func bindSettings() {
        settings.$isEnabled
            .combineLatest(settings.$isImpactDetectionEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled, isImpactDetectionEnabled in
                guard let self else {
                    return
                }

                if isEnabled && isImpactDetectionEnabled {
                    self.motionDetector.start()
                } else {
                    self.motionDetector.stop()
                }

                if !isEnabled {
                    self.soundPlayer.stopAll()
                }

                self.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$trackpadMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.trackpadState.mode = mode
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuildMenu()
                }
            }
            .store(in: &cancellables)
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.title = ""
            button.image = MenuBarIcon.make(isEnabled: settings.isEnabled)
            button.imagePosition = .imageOnly
            button.toolTip = "SquishMac"
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else {
            return
        }

        if let button = statusItem.button {
            button.image = MenuBarIcon.make(isEnabled: settings.isEnabled)
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: settings.isEnabled ? "Turn Off" : "Turn On", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = settings.isEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let packSubmenu = NSMenu()
        for pack in soundPackManager.availablePacks() {
            let item = NSMenuItem(title: pack.title, action: #selector(selectSoundPack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.id
            item.state = settings.selectedSoundPackID == pack.id ? .on : .off
            item.isEnabled = !pack.isCustom || settings.customSoundDirectoryPath != nil
            packSubmenu.addItem(item)
        }

        let packItem = NSMenuItem(title: "Impact Sound Pack", action: nil, keyEquivalent: "")
        packItem.submenu = packSubmenu
        menu.addItem(packItem)

        menu.addItem(NSMenuItem(title: "Played Today: \(settings.todaysCount)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Trackpad Mode: \(settings.trackpadMode.title)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Volume: \(Int(settings.masterVolume * 100))%", action: nil, keyEquivalent: ""))

        if settings.isImpactDetectionEnabled {
            menu.addItem(NSMenuItem(title: "Current Motion: \(String(format: "%.3f", motionDetector.currentStrength)) g", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())

        let testItem = NSMenuItem(title: "Test Sound", action: #selector(playTestSound), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let trackpadItem = NSMenuItem(title: "Open Squish Surface...", action: #selector(openTrackpadLab), keyEquivalent: "t")
        trackpadItem.target = self
        menu.addItem(trackpadItem)

        let recalibrateItem = NSMenuItem(title: "Recalibrate Motion", action: #selector(recalibrateMotion), keyEquivalent: "")
        recalibrateItem.target = self
        recalibrateItem.isEnabled = settings.isEnabled && settings.isImpactDetectionEnabled
        menu.addItem(recalibrateItem)

        let customFolderItem = NSMenuItem(title: "Choose Custom Sound Folder...", action: #selector(chooseCustomSoundFolder), keyEquivalent: "")
        customFolderItem.target = self
        menu.addItem(customFolderItem)

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginMenuState
        launchAtLoginItem.isEnabled = settings.launchAtLoginStatus != .unavailable
        menu.addItem(launchAtLoginItem)

        let resetItem = NSMenuItem(title: "Reset Today Counter", action: #selector(resetCounter), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SquishMac", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func handleImpact(_ impact: MotionImpact) {
        guard settings.isEnabled, settings.isImpactDetectionEnabled else {
            return
        }

        let didPlay = soundPlayer.playRandomSound(
            packID: settings.selectedSoundPackID,
            customDirectoryPath: settings.customSoundDirectoryPath,
            impactStrength: impact.strength,
            sensitivity: settings.sensitivity,
            masterVolume: settings.masterVolume
        )
        if didPlay {
            settings.recordPlay()
        }
        rebuildMenu()
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func selectSoundPack(_ sender: NSMenuItem) {
        guard let packID = sender.representedObject as? String else {
            return
        }

        if packID == SoundPackManager.customPackID && settings.customSoundDirectoryPath == nil {
            chooseCustomSoundFolder()
            return
        }

        settings.selectedSoundPackID = packID
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                motionDetector: motionDetector,
                soundPlayer: soundPlayer,
                soundPackManager: soundPackManager,
                onTestSound: { [weak self] in
                    self?.playPreviewSound()
                },
                onChooseCustomSoundFolder: { [weak self] in
                    self?.chooseCustomSoundFolder()
                },
                onClearCustomSoundFolder: { [weak self] in
                    self?.clearCustomSoundFolder()
                },
                onRevealCustomSoundFolder: { [weak self] in
                    self?.revealCustomSoundFolder()
                },
                onSetLaunchAtLogin: { [weak self] enabled in
                    self?.setLaunchAtLogin(enabled)
                },
                onRecalibrateMotion: { [weak self] in
                    self?.recalibrateMotion()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SquishMac Settings"
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openTrackpadLab() {
        if trackpadWindow == nil {
            let view = TrackpadLabView(
                state: trackpadState,
                settings: settings,
                onGesture: { [weak self] trigger in
                    self?.handleTrackpadGesture(trigger)
                },
                onExportRecording: { [weak self] in
                    self?.exportTrackpadRecording()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 740),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SquishMac Squish Surface"
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            trackpadWindow = window
        }

        trackpadWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleTrackpadGesture(_ trigger: TrackpadGestureTrigger) {
        guard settings.isEnabled else {
            return
        }

        let didPlay = soundPlayer.playInteractionSound(
            kind: trigger.kind,
            intensity: trigger.intensity,
            masterVolume: settings.masterVolume
        )
        if didPlay {
            settings.recordPlay()
        }
        performHapticFeedback(for: trigger.kind)
        rebuildMenu()
    }

    private func performHapticFeedback(for kind: TrackpadSoundKind) {
        guard settings.isHapticFeedbackEnabled else {
            return
        }

        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch kind {
        case .waxCrack:
            pattern = .levelChange
        case .waxCrush:
            pattern = .generic
        case .slimeKnead, .slimeStretch, .slimeRelease, .waxPress:
            return
        }

        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    @objc private func playTestSound() {
        playPreviewSound()
    }

    private func playPreviewSound() {
        soundPlayer.playPreview(
            packID: settings.selectedSoundPackID,
            customDirectoryPath: settings.customSoundDirectoryPath,
            sensitivity: settings.sensitivity,
            masterVolume: settings.masterVolume
        )
    }

    private func exportTrackpadRecording() {
        if trackpadState.isRecording {
            trackpadState.stopRecording()
        }

        do {
            let data = try trackpadState.encodedRecording()
            let panel = NSSavePanel()
            panel.title = "Export Trackpad Session"
            panel.prompt = "Export"
            panel.nameFieldStringValue = recordingFileName()
            panel.allowedFileTypes = ["json"]
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }

            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could Not Export Trackpad Session"
            alert.runModal()
        }
    }

    private func recordingFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "SquishMac-Trackpad-\(formatter.string(from: Date())).json"
    }

    @objc private func chooseCustomSoundFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Custom Sound Folder"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if let customPath = settings.customSoundDirectoryPath {
            panel.directoryURL = URL(fileURLWithPath: customPath)
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        settings.customSoundDirectoryPath = url.path
        settings.selectedSoundPackID = SoundPackManager.customPackID
        rebuildMenu()
    }

    private func clearCustomSoundFolder() {
        settings.customSoundDirectoryPath = nil
        rebuildMenu()
    }

    private func revealCustomSoundFolder() {
        guard let customPath = settings.customSoundDirectoryPath else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: customPath)])
    }

    @objc private func recalibrateMotion() {
        motionDetector.resetCalibration()
    }

    @objc private func toggleLaunchAtLogin() {
        setLaunchAtLogin(settings.launchAtLoginStatus != .enabled)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus(error: error.localizedDescription)
        }

        rebuildMenu()
    }

    private func refreshLaunchAtLoginStatus(error: String? = nil) {
        settings.updateLaunchAtLoginStatus(LoginItemManager.status(), error: error)
    }

    private var launchAtLoginMenuState: NSControl.StateValue {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return .on
        case .requiresApproval, .unknown:
            return .mixed
        case .disabled, .unavailable:
            return .off
        }
    }

    @objc private func resetCounter() {
        settings.resetTodayCount()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        motionDetector.stop()
        soundPlayer.stopAll()
    }
}
