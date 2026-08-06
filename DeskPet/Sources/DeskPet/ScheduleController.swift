import AppKit
import Foundation

/// Decide cuándo debe aparecer la mascota y mantiene el único temporizador
/// activo mientras la app está en estado .hidden.
final class ScheduleController {

    /// Se llama en el hilo principal cuando toca mostrar la mascota.
    var onFire: (() -> Void)?

    private let preferences: Preferences
    private let systemState: SystemStateMonitor
    private let calendar = Calendar.current
    private let launchDate = Date()

    private var timer: Timer?
    private(set) var nextFireDate: Date?

    /// Si está activo, la próxima aparición se salta (y se rearma la siguiente).
    var skipNextReminder = false

    init(preferences: Preferences, systemState: SystemStateMonitor) {
        self.preferences = preferences
        self.systemState = systemState

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Tras dormir, los temporizadores pueden haber quedado desfasados.
            self?.reschedule()
        }
    }

    func start() {
        reschedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        nextFireDate = nil
    }

    func reschedule(from reference: Date = Date()) {
        timer?.invalidate()

        let fireDate = nextDate(after: reference)
        nextFireDate = fireDate

        let timer = Timer(fireAt: fireDate,
                          interval: 0,
                          target: self,
                          selector: #selector(timerFired),
                          userInfo: nil,
                          repeats: false)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func timerFired() {
        defer { reschedule() }

        if skipNextReminder {
            skipNextReminder = false
            NSLog("DeskPet: aviso saltado a petición del usuario.")
            return
        }

        if let blocker = systemState.currentBlocker() {
            NSLog("DeskPet: aviso pospuesto porque \(blocker).")
            return
        }

        onFire?()
    }

    // MARK: - Cálculo de la próxima fecha

    /// Próxima fecha válida según el modo elegido y la franja horaria activa.
    func nextDate(after reference: Date) -> Date {
        var candidate = rawNextDate(after: reference)

        // Como mucho dos días de saltos de una hora: suficiente para cualquier
        // franja horaria, incluidas las que cruzan la medianoche.
        var guardCounter = 0
        while !isInsideActiveWindow(candidate) && guardCounter < 48 {
            candidate = candidate.addingTimeInterval(3600)
            guardCounter += 1
        }
        return candidate
    }

    private func rawNextDate(after reference: Date) -> Date {
        switch preferences.scheduleMode {
        case .onTheHour:
            let components = DateComponents(minute: 0, second: 0)
            return calendar.nextDate(after: reference,
                                     matching: components,
                                     matchingPolicy: .nextTime,
                                     repeatedTimePolicy: .first,
                                     direction: .forward)
                ?? reference.addingTimeInterval(3600)

        case .everyHourFromLaunch:
            let elapsed = reference.timeIntervalSince(launchDate)
            let steps = floor(max(elapsed, 0) / 3600) + 1
            return launchDate.addingTimeInterval(steps * 3600)
        }
    }

    /// La franja es inclusiva en ambos extremos: 9–20 permite avisos a las 20:00.
    func isInsideActiveWindow(_ date: Date) -> Bool {
        let start = preferences.activeStartHourValue
        let end = preferences.activeEndHourValue
        let hour = calendar.component(.hour, from: date)

        if start == end { return true }              // franja de 24 h
        if start < end { return hour >= start && hour <= end }
        return hour >= start || hour <= end          // franja que cruza medianoche
    }
}
