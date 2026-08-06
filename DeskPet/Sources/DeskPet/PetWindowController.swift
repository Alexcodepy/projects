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
    private var currentGeometry: PetGeometry?

    /// Se avisa cuando la mascota ya está colgando (para mostrar la nota).
    private var onSettled: ((CGRect, NSScreen) -> Void)?
    /// Se avisa justo antes de empezar la salida (para ocultar la nota).
    private var onWillExit: (() -> Void)?
    private var onFinished: (() -> Void)?

    init(preferences: Preferences) {
        self.preferences = preferences
        self.animator = PetAnimator(preferences: preferences)

        let initialRect = NSRect(x: 0, y: 0, width: 400, height: 500)
        hostView = PetHostView(frame: initialRect)
        panel = NSPanel(contentRect: initialRect,
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
        hostView.onBackingChange = { [weak self] in
            guard let self, self.state != .hidden else { return }
            self.animator.refreshArtwork(scale: self.panel.backingScaleFactor)
        }

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
            self?.reapplyAppearance()
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

        // El arte se rasteriza a la escala de esta pantalla y de él salen las
        // medidas de la ventana.
        let geometry = animator.prepareArtwork(scale: screen.backingScaleFactor)
        currentGeometry = geometry
        layout(geometry: geometry, on: screen)
        animator.applyGeometry(geometry)

        state = .entering
        panel.orderFrontRegardless()
        startMouseTracking()

        animator.playEntrance { [weak self] in
            guard let self, self.state == .entering else { return }
            self.state = .idle
            self.animator.startIdleSway()
            self.notifySettled()

            // Pirueta a mitad de la estancia y salida al terminar el tiempo.
            self.schedule(after: min(1.6, max(duration * 0.3, 0.8))) { [weak self] in
                self?.performTrick()
            }
            self.schedule(after: max(duration, 2.5)) { [weak self] in
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

    /// Corta el ciclo sin animación (salir de la app).
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
        guard state == .idle || state == .trick else { return }
        cancelPendingWork()
        state = .exiting
        onWillExit?()

        // Deja que la nota termine su fundido antes de que la mascota suba.
        schedule(after: ReminderController.fadeDuration) { [weak self] in
            guard let self, self.state == .exiting else { return }
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
        let rectOnScreen = panel.convertToScreen(animator.petRectInView)
        onSettled?(rectOnScreen, screen)
    }

    // MARK: - Posición

    /// La ventana es bastante más grande que la ilustración: tiene que dar
    /// cabida al círculo que barre la pirueta. Por eso los márgenes se miden
    /// contra el dibujo, no contra el borde de la ventana.
    private func layout(geometry: PetGeometry, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = geometry.windowSize
        let artRect = geometry.petRect(grip: geometry.gripRest)

        var origin = NSPoint(
            x: visible.maxX - preferences.marginRightValue - artRect.maxX,
            y: visible.maxY - preferences.marginTopValue - size.height
        )

        // Que el dibujo no se salga del área visible (la ventana transparente sí
        // puede sobresalir, el personaje no).
        origin.x = min(origin.x, visible.maxX - artRect.maxX)
        origin.x = max(origin.x, visible.minX - artRect.minX)
        origin.y = max(origin.y, visible.minY - artRect.minY)
        origin.y = min(origin.y, visible.maxY - size.height)

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        hostView.frame = NSRect(origin: .zero, size: size)
    }

    private func repositionIfVisible() {
        guard state != .hidden, let geometry = currentGeometry else { return }
        guard let screen = currentScreen ?? PetWindowController.activeScreen() else { return }
        currentScreen = screen
        layout(geometry: geometry, on: screen)
    }

    /// Cambios de arte, tamaño, anclaje o balanceo: se aplican al instante si la
    /// mascota está colgando tranquila; en plena transición esperan al siguiente
    /// ciclo para no cortar una animación por la mitad.
    private func reapplyAppearance() {
        ArtworkProvider.invalidate()
        guard state == .idle, let screen = currentScreen else { return }

        animator.stopIdleSway()
        let geometry = animator.prepareArtwork(scale: screen.backingScaleFactor)
        currentGeometry = geometry
        layout(geometry: geometry, on: screen)
        animator.applyGeometry(geometry)
        animator.settleAtRest()
        animator.startIdleSway()
        updateMouseTransparency()
    }

    /// Pantalla donde está el cursor; si no se puede saber, la principal.
    static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    // MARK: - Ratón

    /// La ventana solo intercepta el ratón cuando el cursor está sobre el
    /// dibujo; el resto del tiempo los clics pasan a las apps de debajo.
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
