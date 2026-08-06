import AppKit

/// Estados explícitos del ciclo de vida de la mascota.
enum PetState {
    case hidden
    case entering
    case idle
    case trick
    case exiting
}

/// Gestiona el NSPanel de la mascota y orquesta la máquina de estados.
final class PetWindowController {

    private(set) var state: PetState = .hidden

    private let preferences: Preferences
    private let animator: PetAnimator
    private let hostView: PetHostView
    private let panel: NSPanel

    private var pendingWork: [DispatchWorkItem] = []
    private var mouseMonitor: Any?
    private var currentScreen: NSScreen?

    /// Se avisa cuando la mascota ya está colgando (para mostrar la nota).
    private var onSettled: ((CGRect, NSScreen) -> Void)?
    /// Se avisa justo antes de empezar la salida (para ocultar la nota).
    private var onWillExit: (() -> Void)?
    private var onFinished: (() -> Void)?

    init(preferences: Preferences) {
        self.preferences = preferences
        self.animator = PetAnimator(preferences: preferences)

        let geometry = PetGeometry(petSize: preferences.petSizeValue)
        let contentRect = NSRect(origin: .zero, size: geometry.windowSize)

        hostView = PetHostView(frame: contentRect)
        panel = NSPanel(contentRect: contentRect,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = false
        panel.contentView = hostView

        animator.attach(to: hostView)
        hostView.onClick = { [weak self] in self?.dismissEarly() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.repositionIfVisible()
        }

        NotificationCenter.default.addObserver(
            forName: .deskPetAppearanceSettingsChanged,
            object: nil, queue: .main
        ) { [weak self] _ in
            SpriteProvider.invalidate()
            self?.repositionIfVisible()
        }
    }

    // MARK: - Ciclo completo

    func present(duration: TimeInterval,
                 onSettled: @escaping (CGRect, NSScreen) -> Void,
                 onWillExit: @escaping () -> Void,
                 onFinished: @escaping () -> Void) {

        guard state == .hidden else { return }
        guard let screen = PetWindowController.activeScreen() else { return }

        self.onSettled = onSettled
        self.onWillExit = onWillExit
        self.onFinished = onFinished
        currentScreen = screen

        let geometry = PetGeometry(petSize: preferences.petSizeValue)
        layout(geometry: geometry, on: screen)
        animator.prepare(geometry: geometry)

        state = .entering
        panel.orderFrontRegardless()
        startMouseTracking()

        animator.playEntrance { [weak self] in
            guard let self, self.state == .entering else { return }
            self.state = .idle
            self.animator.startIdleSway()
            self.notifySettled()

            // Pirueta a mitad de la estancia y salida al terminar el tiempo.
            self.schedule(after: min(1.4, max(duration * 0.25, 0.6))) { [weak self] in
                self?.performTrick()
            }
            self.schedule(after: max(duration, 2.0)) { [weak self] in
                self?.beginExit()
            }
        }
    }

    /// Clic sobre la mascota: se marcha antes de tiempo.
    func dismissEarly() {
        switch state {
        case .idle, .trick:
            beginExit()
        case .entering:
            // Espera a estar colgando para no cortar la entrada a medias.
            schedule(after: PetAnimator.entranceDuration) { [weak self] in
                guard let self, self.state == .idle || self.state == .trick else { return }
                self.beginExit()
            }
        case .exiting, .hidden:
            break
        }
    }

    /// Corta el ciclo sin animación (salir de la app, cambios de ajustes).
    func hideImmediately() {
        cancelPendingWork()
        onWillExit?()
        animator.teardown()
        stopMouseTracking()
        panel.orderOut(nil)
        state = .hidden
        onFinished?()
        clearCallbacks()
    }

    // MARK: - Fases internas

    private func performTrick() {
        guard state == .idle else { return }
        state = .trick
        animator.playTrick { [weak self] in
            guard let self, self.state == .trick else { return }
            self.state = .idle
        }
    }

    private func beginExit() {
        guard state == .idle || state == .trick || state == .entering else { return }
        cancelPendingWork()
        state = .exiting
        onWillExit?()

        // Deja que la nota termine su fundido antes de que la mascota suba.
        schedule(after: ReminderController.fadeDuration) { [weak self] in
            guard let self, self.state == .exiting else { return }
            self.animator.stopIdleSway()
            self.animator.playExit { [weak self] in
                guard let self, self.state == .exiting else { return }
                self.finishCycle()
            }
        }
    }

    private func finishCycle() {
        cancelPendingWork()
        animator.teardown()
        stopMouseTracking()
        panel.orderOut(nil)
        state = .hidden
        onFinished?()
        clearCallbacks()
    }

    private func clearCallbacks() {
        onSettled = nil
        onWillExit = nil
        onFinished = nil
    }

    private func notifySettled() {
        guard let screen = currentScreen else { return }
        let rectInWindow = animator.petRectInView
        let rectOnScreen = panel.convertToScreen(rectInWindow)
        onSettled?(rectOnScreen, screen)
    }

    // MARK: - Posición

    private func layout(geometry: PetGeometry, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = geometry.windowSize
        var origin = NSPoint(
            x: visible.maxX - preferences.marginRightValue - size.width,
            y: visible.maxY - preferences.marginTopValue - size.height
        )
        // No dejar la ventana fuera del área visible en pantallas pequeñas.
        origin.x = min(max(origin.x, visible.minX), max(visible.maxX - size.width, visible.minX))
        origin.y = min(max(origin.y, visible.minY), max(visible.maxY - size.height, visible.minY))

        hostView.frame = NSRect(origin: .zero, size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func repositionIfVisible() {
        guard state != .hidden else { return }
        guard let screen = currentScreen ?? PetWindowController.activeScreen() else { return }
        currentScreen = screen
        let geometry = PetGeometry(petSize: preferences.petSizeValue)
        layout(geometry: geometry, on: screen)
    }

    /// Pantalla donde está el cursor; si no se puede saber, la principal.
    static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    // MARK: - Ratón

    /// La ventana solo intercepta el ratón cuando el cursor está sobre el sprite;
    /// el resto del tiempo los clics pasan a las apps de debajo.
    private func startMouseTracking() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.updateMouseTransparency()
        }
        updateMouseTransparency()
    }

    private func stopMouseTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        panel.ignoresMouseEvents = true
    }

    private func updateMouseTransparency() {
        guard state != .hidden else {
            panel.ignoresMouseEvents = true
            return
        }
        let petRectOnScreen = panel.convertToScreen(animator.petRectInView).insetBy(dx: -8, dy: -8)
        panel.ignoresMouseEvents = !NSMouseInRect(NSEvent.mouseLocation, petRectOnScreen, false)
    }

    // MARK: - Temporización interna

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        pendingWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingWork() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }
}
