import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import SwiftUI

extension Notification.Name {
    /// Se emite cuando cambia algo que afecta al temporizador de aparición.
    static let deskPetScheduleSettingsChanged = Notification.Name("DeskPetScheduleSettingsChanged")
    /// Se emite cuando cambia algo que afecta al aspecto (tamaño, sprites, posición).
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
        static let petSize = "petSize"
        static let messages = "messages"
        static let messageIndex = "messageIndex"
        static let spriteSheetPath = "spriteSheetPath"
        static let spriteColumns = "spriteColumns"
        static let spriteRows = "spriteRows"
        static let spriteFPS = "spriteFPS"
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

    /// Lado del sprite de la mascota en puntos.
    @Published var petSize: Double {
        didSet {
            defaults.set(petSize, forKey: Key.petSize)
            notifyAppearance()
        }
    }

    var petSizeValue: CGFloat { CGFloat(min(max(petSize, 60), 400)) }

    @Published var messages: [String] {
        didSet { defaults.set(messages, forKey: Key.messages) }
    }

    // MARK: - Sprites

    /// Ruta a un sprite sheet propio. Vacío = sprites del bundle o generados.
    @Published var spriteSheetPath: String {
        didSet {
            defaults.set(spriteSheetPath, forKey: Key.spriteSheetPath)
            notifyAppearance()
        }
    }

    @Published var spriteColumns: Int {
        didSet {
            defaults.set(spriteColumns, forKey: Key.spriteColumns)
            notifyAppearance()
        }
    }

    @Published var spriteRows: Int {
        didSet {
            defaults.set(spriteRows, forKey: Key.spriteRows)
            notifyAppearance()
        }
    }

    @Published var spriteFPS: Double {
        didSet {
            defaults.set(spriteFPS, forKey: Key.spriteFPS)
            notifyAppearance()
        }
    }

    var spriteColumnsValue: Int { min(max(spriteColumns, 1), 32) }
    var spriteRowsValue: Int { min(max(spriteRows, 1), 32) }
    var spriteFPSValue: Double { min(max(spriteFPS, 1), 60) }

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
            Key.petSize: 140.0,
            Key.messages: Preferences.defaultMessages,
            Key.messageIndex: 0,
            Key.spriteSheetPath: "",
            Key.spriteColumns: 6,
            Key.spriteRows: 2,
            Key.spriteFPS: 8.0,
            Key.marginTop: 0.0,
            Key.marginRight: 40.0
        ])

        // Los observadores didSet no se disparan durante init: aquí solo se carga.
        let rawMode = defaults.string(forKey: Key.scheduleMode) ?? ScheduleMode.onTheHour.rawValue
        scheduleMode = ScheduleMode(rawValue: rawMode) ?? .onTheHour
        activeStartHour = defaults.integer(forKey: Key.activeStartHour)
        activeEndHour = defaults.integer(forKey: Key.activeEndHour)
        onScreenDuration = defaults.double(forKey: Key.onScreenDuration)
        petSize = defaults.double(forKey: Key.petSize)
        let storedMessages = defaults.stringArray(forKey: Key.messages) ?? Preferences.defaultMessages
        messages = storedMessages.isEmpty ? Preferences.defaultMessages : storedMessages
        spriteSheetPath = defaults.string(forKey: Key.spriteSheetPath) ?? ""
        spriteColumns = defaults.integer(forKey: Key.spriteColumns)
        spriteRows = defaults.integer(forKey: Key.spriteRows)
        spriteFPS = defaults.double(forKey: Key.spriteFPS)
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
