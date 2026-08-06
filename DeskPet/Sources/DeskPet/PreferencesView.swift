import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {

    @ObservedObject var prefs: Preferences

    var body: some View {
        TabView {
            GeneralTab(prefs: prefs)
                .tabItem { Text("General") }
            MessagesTab(prefs: prefs)
                .tabItem { Text("Mensajes") }
            AppearanceTab(prefs: prefs)
                .tabItem { Text("Apariencia") }
        }
        .padding(16)
        .frame(width: 540, height: 460)
    }
}

// MARK: - General

private struct GeneralTab: View {

    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Picker("Programación:", selection: $prefs.scheduleMode) {
                ForEach(ScheduleMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            HStack {
                Picker("Franja activa:", selection: $prefs.activeStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .frame(width: 190)

                Picker("hasta", selection: $prefs.activeEndHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .frame(width: 140)
            }

            Text("Fuera de esa franja el aviso se pospone al siguiente ciclo. "
                 + "Si ambas horas coinciden, DeskPet estará activo las 24 h.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading) {
                Slider(value: $prefs.onScreenDuration, in: 3...60, step: 1) {
                    Text("Tiempo en pantalla:")
                }
                Text("\(Int(prefs.onScreenDuration)) segundos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Toggle("Abrir DeskPet al iniciar sesión", isOn: $prefs.launchAtLogin)

            Text("El arranque automático necesita que la app esté en /Applications "
                 + "y firmada; si falla, el interruptor vuelve a su posición.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

// MARK: - Mensajes

private struct MessagesTab: View {

    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Los mensajes se muestran por turnos, uno en cada aviso.")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(prefs.messages.indices, id: \.self) { index in
                    HStack {
                        TextField("Mensaje", text: binding(for: index))
                            .textFieldStyle(.roundedBorder)
                        Button {
                            prefs.removeMessage(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Eliminar mensaje")
                    }
                }
            }
            .frame(minHeight: 250)

            HStack {
                Button("Añadir mensaje") { prefs.addMessage() }
                Spacer()
                Button("Restablecer los de fábrica") { prefs.restoreDefaultMessages() }
            }
        }
        .padding(.top, 8)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { prefs.messages.indices.contains(index) ? prefs.messages[index] : "" },
            set: { newValue in
                guard prefs.messages.indices.contains(index) else { return }
                prefs.messages[index] = newValue
            }
        )
    }
}

// MARK: - Apariencia

private struct AppearanceTab: View {

    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Slider(value: $prefs.petSize, in: 60...300, step: 10) {
                    Text("Tamaño de la mascota:")
                }
                Text("\(Int(prefs.petSize)) px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                TextField("Margen superior", value: $prefs.marginTop, formatter: NumberFormatter())
                    .frame(width: 80)
                Text("px desde arriba")
                TextField("Margen derecho", value: $prefs.marginRight, formatter: NumberFormatter())
                    .frame(width: 80)
                Text("px desde la derecha")
            }

            Divider()

            HStack {
                TextField("Sprite sheet", text: $prefs.spriteSheetPath)
                    .truncationMode(.head)
                Button("Elegir…") { chooseSpriteSheet() }
                Button("Por defecto") { prefs.spriteSheetPath = "" }
            }

            HStack {
                Stepper(value: $prefs.spriteColumns, in: 1...32) {
                    Text("Columnas: \(prefs.spriteColumns)")
                }
                Stepper(value: $prefs.spriteRows, in: 1...32) {
                    Text("Filas: \(prefs.spriteRows)")
                }
            }

            VStack(alignment: .leading) {
                Slider(value: $prefs.spriteFPS, in: 1...24, step: 1) {
                    Text("Velocidad:")
                }
                Text("\(Int(prefs.spriteFPS)) fotogramas por segundo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Fila 0 (la de arriba del PNG) = colgado en reposo. "
                 + "Fila 1 = pirueta. Si dejas la ruta vacía se usan los sprites "
                 + "dibujados por la propia app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func chooseSpriteSheet() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.png]
        panel.message = "Elige el sprite sheet de la mascota"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            prefs.spriteSheetPath = url.path
        }
    }
}

/// Ventana que aloja la interfaz SwiftUI de preferencias.
final class PreferencesWindowController: NSWindowController {

    convenience init(preferences: Preferences) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferencias de DeskPet"
        window.contentView = NSHostingView(rootView: PreferencesView(prefs: preferences))
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
