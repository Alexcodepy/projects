import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import SwiftUI

extension Notification.Name {
    /// Se emite cuando cambia algo que afecta al temporizador de aparición.
    static let deskPetScheduleSettingsChanged = Notification.Name("DeskPetScheduleSettingsChanged")
    /// Se emite cuando cambia algo que afecta al aspecto (arte, tamaño, anclaje…).
    static let deskPetAppearanceSettingsChanged = Notification.Name("DeskPetAppearanceSettingsChanged")
}

enum ScheduleMode: String, CaseIterable, Identifiable {
    case onTheHour
    case everyHourFromLaunch

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .onTheHour: return "En punto (10:00, 11:00…)"
        case .everyHourFromLaunch: return "Cada 60 min desde el arranque"
        }
    }
}

/// Todos los ajustes de la app, persistidos en UserDefaults.
///
/// Nota de implementación: los `didSet` no reasignan nunca su propia propiedad
/// (con `@Published` eso provocaría recursión infinita). Los límites se aplican
/// en las propiedades derivadas `…Value` que consume el resto de la app.
final class Preferences: ObservableObject {

    static let shared = Preferences()

    private enum Key {
        static let scheduleMode = "scheduleMode"
        static let activeStartHour = "activeStartHour"
        static let activeEndHour = "activeEndHour"
        static let onScreenDuration = "onScreenDuration"
        static let petHeight = "petHeight"
        static let messages = "messages"
        static let messageIndex = "messageIndex"
        static let artworkPath = "artworkPath"
        static let trickArtworkPath = "trickArtworkPath"
        static let anchorX = "anchorX"
        static let anchorY = "anchorY"
        static let swingDegrees = "swingDegrees"
        static let marginTop = "marginTop"
        static let marginRight = "marginRight"
    }

    static let defaultMessages = [
        "Levántate y estira",
        "Descansa la vista 20 segundos",
        "Bebe un poco de agua",
        "Respira hondo tres veces",
        "Mueve hombros y cuello"
    ]

    private let defaults: UserDefaults
    private var isApplyingLoginItem = false

    // MARK: - Programación

    @Published var scheduleMode: ScheduleMode {
        didSet {
            defaults.set(scheduleMode.rawValue, forKey: Key.scheduleMode)
            notifySchedule()
        }
    }

    /// Hora (0-23) a partir de la cual DeskPet puede aparecer.
    @Published var activeStartHour: Int {
        didSet {
            defaults.set(activeStartHour, forKey: Key.activeStartHour)
            notifySchedule()
        }
    }

    /// Última hora (0-23) en la que DeskPet puede aparecer (inclusive).
    @Published var activeEndHour: Int {
        didSet {
            defaults.set(activeEndHour, forKey: Key.activeEndHour)
            notifySchedule()
        }
    }

    var activeStartHourValue: Int { min(max(activeStartHour, 0), 23) }
    var activeEndHourValue: Int { min(max(activeEndHour, 0), 23) }

    // MARK: - Presentación

    /// Segundos que la mascota permanece visible antes de irse.
    @Published var onScreenDuration: Double {
        didSet { defaults.set(onScreenDuration, forKey: Key.onScreenDuration) }
    }

    var onScreenDurationValue: TimeInterval { min(max(onScreenDuration, 3), 300) }

    /// Altura de la ilustración en puntos.
    @Published var petHeight: Double {
        didSet {
            defaults.set(petHeight, forKey: Key.petHeight)
            notifyAppearance()
        }
    }

    var petHeightValue: CGFloat { CGFloat(min(max(petHeight, 80), 600)) }

    /// Amplitud del balanceo en grados.
    @Published var swingDegrees: Double {
        didSet {
            defaults.set(swingDegrees, forKey: Key.swingDegrees)
            notifyAppearance()
        }
    }

    var swingAmplitudeRadians: CGFloat {
        CGFloat(min(max(swingDegrees, 0), 30) * Double.pi / 180)
    }

    @Published var messages: [String] {
        didSet { defaults.set(messages, forKey: Key.messages) }
    }

    // MARK: - Ilustración

    /// Ruta a la ilustración principal (PDF, PNG…). Vacío = silueta de respaldo.
    @Published var artworkPath: String {
        didSet {
            defaults.set(artworkPath, forKey: Key.artworkPath)
            notifyAppearance()
        }
    }

    /// Ruta a la pose recogida para la pirueta. Opcional.
    @Published var trickArtworkPath: String {
        didSet {
            defaults.set(trickArtworkPath, forKey: Key.trickArtworkPath)
            notifyAppearance()
        }
    }

    /// Punto donde las manos agarran el hilo, en espacio unitario del layer.
    /// (0.5, 1.0) = centro del borde superior de la ilustración.
    @Published var anchorX: Double {
        didSet {
            defaults.set(anchorX, forKey: Key.anchorX)
            notifyAppearance()
        }
    }

    @Published var anchorY: Double {
        didSet {
            defaults.set(anchorY, forKey: Key.anchorY)
            notifyAppearance()
        }
    }

    var anchorPointValue: CGPoint {
        CGPoint(x: min(max(anchorX, 0), 1), y: min(max(anchorY, 0), 1))
    }

    // MARK: - Posición

    /// Distancia desde el borde superior del área visible de la pantalla.
    @Published var marginTop: Double {
        didSet {
            defaults.set(marginTop, forKey: Key.marginTop)
            notifyAppearance()
        }
    }

    /// Distancia desde el borde derecho del área visible de la pantalla.
    @Published var marginRight: Double {
        didSet {
            defaults.set(marginRight, forKey: Key.marginRight)
            notifyAppearance()
        }
    }

    var marginTopValue: CGFloat { CGFloat(min(max(marginTop, 0), 4000)) }
    var marginRightValue: CGFloat { CGFloat(min(max(marginRight, 0), 4000)) }

    // MARK: - Inicio de sesión

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isApplyingLoginItem else { return }
            applyLaunchAtLogin()
        }
    }

    // MARK: - Init

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Key.scheduleMode: ScheduleMode.onTheHour.rawValue,
            Key.activeStartHour: 9,
            Key.activeEndHour: 20,
            Key.onScreenDuration: 10.0,
            Key.petHeight: 220.0,
            Key.messages: Preferences.defaultMessages,
            Key.messageIndex: 0,
            Key.artworkPath: "",
            Key.trickArtworkPath: "",
            Key.anchorX: 0.5,
            Key.anchorY: 1.0,
            Key.swingDegrees: 6.0,
            Key.marginTop: 0.0,
            Key.marginRight: 40.0
        ])

        // Los observadores didSet no se disparan durante init: aquí solo se carga.
        let rawMode = defaults.string(forKey: Key.scheduleMode) ?? ScheduleMode.onTheHour.rawValue
        scheduleMode = ScheduleMode(rawValue: rawMode) ?? .onTheHour
        activeStartHour = defaults.integer(forKey: Key.activeStartHour)
        activeEndHour = defaults.integer(forKey: Key.activeEndHour)
        onScreenDuration = defaults.double(forKey: Key.onScreenDuration)
        petHeight = defaults.double(forKey: Key.petHeight)
        swingDegrees = defaults.double(forKey: Key.swingDegrees)
        let storedMessages = defaults.stringArray(forKey: Key.messages) ?? Preferences.defaultMessages
        messages = storedMessages.isEmpty ? Preferences.defaultMessages : storedMessages
        artworkPath = defaults.string(forKey: Key.artworkPath) ?? ""
        trickArtworkPath = defaults.string(forKey: Key.trickArtworkPath) ?? ""
        anchorX = defaults.double(forKey: Key.anchorX)
        anchorY = defaults.double(forKey: Key.anchorY)
        marginTop = defaults.double(forKey: Key.marginTop)
        marginRight = defaults.double(forKey: Key.marginRight)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Mensajes rotatorios

    func nextMessage() -> String {
        let pool = messages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !pool.isEmpty else { return Preferences.defaultMessages[0] }
        let index = abs(defaults.integer(forKey: Key.messageIndex)) % pool.count
        defaults.set((index + 1) % pool.count, forKey: Key.messageIndex)
        return pool[index]
    }

    func addMessage() {
        messages.append("Nuevo recordatorio")
    }

    func removeMessage(at index: Int) {
        guard messages.indices.contains(index) else { return }
        var updated = messages
        updated.remove(at: index)
        messages = updated.isEmpty ? Preferences.defaultMessages : updated
    }

    func restoreDefaultMessages() {
        messages = Preferences.defaultMessages
    }

    // MARK: - Helpers

    private func notifySchedule() {
        NotificationCenter.default.post(name: .deskPetScheduleSettingsChanged, object: self)
    }

    private func notifyAppearance() {
        NotificationCenter.default.post(name: .deskPetAppearanceSettingsChanged, object: self)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DeskPet: no se pudo cambiar el arranque automático: \(error.localizedDescription)")
            let corrected = !launchAtLogin
            isApplyingLoginItem = true
            launchAtLogin = corrected
            isApplyingLoginItem = false
        }
    }
}
