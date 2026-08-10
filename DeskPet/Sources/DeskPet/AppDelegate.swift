import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let preferences = Preferences.shared
    private let systemState = SystemStateMonitor()

    private var statusItem: NSStatusItem?
    private var scheduler: ScheduleController!
    private var petController: PetWindowController!
    private var reminderController: ReminderController!
    private var preferencesWindowController: PreferencesWindowController?

    private var nextFireItem: NSMenuItem?
    private var skipItem: NSMenuItem?

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter
    }()

    // MARK: - Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        petController = PetWindowController(preferences: preferences)
        reminderController = ReminderController(preferences: preferences)
        scheduler = ScheduleController(preferences: preferences, systemState: systemState)
        scheduler.onFire = { [weak self] in self?.startCycle() }

        buildStatusItem()
        scheduler.start()

        NotificationCenter.default.addObserver(
            forName: .deskPetScheduleSettingsChanged,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduler.reschedule()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
        reminderController?.hideImmediately()
        petController?.hideImmediately()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Barra de menús

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "ant.fill", accessibilityDescription: "DeskPet")
            button.image?.isTemplate = true
            if button.image == nil { button.title = "🕷" }
        }

        let menu = NSMenu()
        menu.delegate = self

        let nextItem = NSMenuItem(title: "Próximo aviso: —", action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)
        nextFireItem = nextItem

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Mostrar ahora",
                                action: #selector(showNow),
                                keyEquivalent: "s"))

        let skip = NSMenuItem(title: "Saltar próximo aviso",
                              action: #selector(toggleSkipNext),
                              keyEquivalent: "")
        menu.addItem(skip)
        skipItem = skip

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferencias…",
                                action: #selector(openPreferences),
                                keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de DeskPet",
                                action: #selector(quit),
                                keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let date = scheduler.nextFireDate {
            nextFireItem?.title = "Próximo aviso: \(timeFormatter.string(from: date))"
        } else {
            nextFireItem?.title = "Próximo aviso: —"
        }
        skipItem?.state = scheduler.skipNextReminder ? .on : .off
    }

    // MARK: - Acciones

    @objc private func showNow() {
        startCycle()
    }

    @objc private func toggleSkipNext() {
        scheduler.skipNextReminder.toggle()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(preferences: preferences)
        }
        preferencesWindowController?.present()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Ciclo de la mascota

    private func startCycle() {
        guard petController.state == .hidden else { return }

        let message = preferences.nextMessage()
        petController.present(
            duration: preferences.onScreenDurationValue,
            onSettled: { [weak self] petRect, screen in
                self?.reminderController.show(message: message, anchoredTo: petRect, on: screen)
            },
            onWillExit: { [weak self] in
                self?.reminderController.hide()
            },
            onFinished: { }
        )
    }
}
