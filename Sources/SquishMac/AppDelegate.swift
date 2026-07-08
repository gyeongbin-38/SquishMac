import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let soundPackManager = SoundPackManager()
    private lazy var soundPlayer = SoundPlayer(packManager: soundPackManager)
    private lazy var motionDetector = MotionDetector(settings: settings)

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        bindSettings()

        motionDetector.onImpact = { [weak self] impact in
            self?.handleImpact(impact)
        }

        if settings.isEnabled {
            motionDetector.start()
        }
    }

    private func bindSettings() {
        settings.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                guard let self else {
                    return
                }

                if isEnabled {
                    self.motionDetector.start()
                } else {
                    self.motionDetector.stop()
                }

                self.rebuildMenu()
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
        for pack in soundPackManager.availablePacks {
            let item = NSMenuItem(title: pack.title, action: #selector(selectSoundPack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.id
            item.state = settings.selectedSoundPackID == pack.id ? .on : .off
            packSubmenu.addItem(item)
        }

        let packItem = NSMenuItem(title: "Sound Pack", action: nil, keyEquivalent: "")
        packItem.submenu = packSubmenu
        menu.addItem(packItem)

        menu.addItem(NSMenuItem(title: "Played Today: \(settings.todaysCount)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Sensitivity: \(String(format: "%.2f", settings.sensitivity)) g", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Cooldown: \(String(format: "%.2f", settings.cooldown)) s", action: nil, keyEquivalent: ""))

        menu.addItem(.separator())

        let testItem = NSMenuItem(title: "Test Sound", action: #selector(playTestSound), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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
        guard settings.isEnabled else {
            return
        }

        soundPlayer.playRandomSound(
            packID: settings.selectedSoundPackID,
            impactStrength: impact.strength,
            sensitivity: settings.sensitivity
        )
        settings.recordPlay()
        rebuildMenu()
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func selectSoundPack(_ sender: NSMenuItem) {
        guard let packID = sender.representedObject as? String else {
            return
        }

        settings.selectedSoundPackID = packID
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                motionDetector: motionDetector,
                soundPackManager: soundPackManager,
                onTestSound: { [weak self] in
                    self?.playPreviewSound()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
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

    @objc private func playTestSound() {
        playPreviewSound()
    }

    private func playPreviewSound() {
        soundPlayer.playPreview(packID: settings.selectedSoundPackID, sensitivity: settings.sensitivity)
    }

    @objc private func resetCounter() {
        settings.resetTodayCount()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
