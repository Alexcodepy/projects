import AppKit
import CoreGraphics

/// Motivos por los que conviene posponer una aparición.
enum PresentationBlocker: CustomStringConvertible {
    case screenLocked
    case systemSleeping
    case fullScreenApp
    case noScreen

    var description: String {
        switch self {
        case .screenLocked: return "la pantalla está bloqueada"
        case .systemSleeping: return "el Mac está en reposo"
        case .fullScreenApp: return "hay una app en pantalla completa"
        case .noScreen: return "no hay pantalla disponible"
        }
    }
}

/// Vigila el estado del sistema para no molestar en mal momento.
final class SystemStateMonitor {

    private(set) var isSleeping = false
    private(set) var isScreenLocked = false

    init() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification,
                                    object: nil, queue: .main) { [weak self] _ in
            self?.isSleeping = true
        }
        workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                    object: nil, queue: .main) { [weak self] _ in
            self?.isSleeping = false
        }
        workspaceCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                    object: nil, queue: .main) { [weak self] _ in
            self?.isSleeping = true
        }
        workspaceCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                    object: nil, queue: .main) { [weak self] _ in
            self?.isSleeping = false
        }

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"),
                                object: nil, queue: .main) { [weak self] _ in
            self?.isScreenLocked = true
        }
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"),
                                object: nil, queue: .main) { [weak self] _ in
            self?.isScreenLocked = false
        }
    }

    /// Devuelve el primer impedimento encontrado, o nil si se puede aparecer.
    func currentBlocker() -> PresentationBlocker? {
        if isSleeping { return .systemSleeping }
        if isScreenLocked || isSessionLocked() { return .screenLocked }
        if NSScreen.screens.isEmpty { return .noScreen }
        if hasFullScreenWindow() { return .fullScreenApp }
        return nil
    }

    // MARK: - Detalles

    /// Consulta directa al servidor de ventanas: cubre el caso de que la app se
    /// lance con la sesión ya bloqueada (sin haber recibido la notificación).
    private func isSessionLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let locked = session["CGSSessionScreenIsLocked"] as? Bool { return locked }
        if let locked = session["CGSSessionScreenIsLocked"] as? Int { return locked != 0 }
        return false
    }

    /// Heurística: busca una ventana normal (nivel 0) de otra app que ocupe
    /// exactamente una pantalla completa. No usa API privada.
    private func hasFullScreenWindow() -> Bool {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let screenRects = SystemStateMonitor.screenRectsInCoreGraphicsSpace()
        guard !screenRects.isEmpty else { return false }

        for window in info {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let pid = window[kCGWindowOwnerPID as String] as? Int, pid == ownPID { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }

            for screen in screenRects where SystemStateMonitor.rect(bounds, matches: screen) {
                return true
            }
        }
        return false
    }

    /// NSScreen usa origen abajo-izquierda; CGWindowList usa arriba-izquierda.
    private static func screenRectsInCoreGraphicsSpace() -> [CGRect] {
        guard let reference = NSScreen.screens.first?.frame else { return [] }
        return NSScreen.screens.map { screen in
            let frame = screen.frame
            return CGRect(x: frame.origin.x,
                          y: reference.maxY - frame.maxY,
                          width: frame.width,
                          height: frame.height)
        }
    }

    private static func rect(_ rect: CGRect, matches screen: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(rect.origin.x - screen.origin.x) <= tolerance &&
        abs(rect.origin.y - screen.origin.y) <= tolerance &&
        abs(rect.width - screen.width) <= tolerance &&
        abs(rect.height - screen.height) <= tolerance
    }
}
