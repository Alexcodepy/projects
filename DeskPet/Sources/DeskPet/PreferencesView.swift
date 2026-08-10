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
        .frame(width: 580, height: 560)
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
            .frame(minHeight: 300)

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Arte
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ilustración").font(.headline)

                    HStack {
                        TextField("Pose normal", text: $prefs.artworkPath)
                            .truncationMode(.head)
                        Button("Elegir…") { chooseArtwork(forTrick: false) }
                        Button("Quitar") { prefs.artworkPath = "" }
                    }

                    HStack {
                        TextField("Pose recogida (opcional)", text: $prefs.trickArtworkPath)
                            .truncationMode(.head)
                        Button("Elegir…") { chooseArtwork(forTrick: true) }
                        Button("Quitar") { prefs.trickArtworkPath = "" }
                    }

                    Text("Una sola imagen con transparencia. PDF vectorial es lo ideal "
                         + "(escala sin pérdida); PNG grande también sirve. El personaje "
                         + "debe colgar con las manos agarrando el hilo en la parte alta "
                         + "de la imagen. La pose recogida solo se usa durante la pirueta.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Anclaje con vista previa
                VStack(alignment: .leading, spacing: 6) {
                    Text("Punto de agarre").font(.headline)

                    HStack(alignment: .top, spacing: 16) {
                        AnchorPreview(prefs: prefs)
                            .frame(width: 150, height: 200)

                        VStack(alignment: .leading) {
                            Slider(value: $prefs.anchorX, in: 0...1) {
                                Text("Horizontal:")
                            }
                            Text(String(format: "X = %.2f", prefs.anchorX))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $prefs.anchorY, in: 0...1) {
                                Text("Vertical:")
                            }
                            Text(String(format: "Y = %.2f  (1,00 = borde superior)", prefs.anchorY))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Centro arriba (0,50 · 1,00)") {
                                prefs.anchorX = 0.5
                                prefs.anchorY = 1.0
                            }
                            .padding(.top, 4)

                            Text("La cruz roja marca dónde se engancha el hilo. Todos los "
                                 + "giros pivotan sobre ese punto.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()

                // Tamaño y movimiento
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tamaño y movimiento").font(.headline)

                    Slider(value: $prefs.petHeight, in: 80...500, step: 10) {
                        Text("Altura:")
                    }
                    Text("\(Int(prefs.petHeight)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $prefs.swingDegrees, in: 0...20, step: 1) {
                        Text("Balanceo:")
                    }
                    Text("± \(Int(prefs.swingDegrees))°")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Margen superior", value: $prefs.marginTop, formatter: NumberFormatter())
                            .frame(width: 70)
                        Text("px desde arriba")
                        TextField("Margen derecho", value: $prefs.marginRight, formatter: NumberFormatter())
                            .frame(width: 70)
                        Text("px desde la derecha")
                    }
                    .padding(.top, 4)
                }

                Text("Los cambios se aplican al instante. Si la mascota está en plena "
                     + "bajada o subida, se aplican en la siguiente aparición.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }

    private func chooseArtwork(forTrick: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.pdf, UTType.png, UTType.svg,
                                     UTType.tiff, UTType.jpeg, UTType.image]
        panel.message = forTrick
            ? "Elige la ilustración de la pose recogida"
            : "Elige la ilustración de la mascota"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            if forTrick {
                prefs.trickArtworkPath = url.path
            } else {
                prefs.artworkPath = url.path
            }
        }
    }
}

/// Vista previa en vivo: la ilustración con una cruz en el punto de anclaje.
private struct AnchorPreview: View {

    @ObservedObject var prefs: Preferences
    /// Se lee del disco solo al cambiar la ruta, no en cada refresco.
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            let box = fittedRect(imageSize: image?.size, in: proxy.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.12))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: box.width, height: box.height)
                        .offset(x: box.minX, y: box.minY)
                } else {
                    Text("Sin ilustración\n(silueta de respaldo)")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(width: proxy.size.width)
                        .offset(y: proxy.size.height / 2 - 14)
                }

                // Cruz de anclaje: en SwiftUI la Y crece hacia abajo, por eso 1 - anchorY.
                Path { path in
                    let x = box.minX + box.width * CGFloat(prefs.anchorX)
                    let y = box.minY + box.height * CGFloat(1 - prefs.anchorY)
                    path.move(to: CGPoint(x: x - 8, y: y))
                    path.addLine(to: CGPoint(x: x + 8, y: y))
                    path.move(to: CGPoint(x: x, y: y - 8))
                    path.addLine(to: CGPoint(x: x, y: y + 8))
                }
                .stroke(Color.red, lineWidth: 1.5)
            }
        }
        .onAppear { reloadImage() }
        .onChange(of: prefs.artworkPath) { _ in reloadImage() }
    }

    private func reloadImage() {
        image = ArtworkProvider.loadImage(path: prefs.artworkPath)
    }

    /// Encaja la imagen (o un rectángulo 0,62:1) dentro del recuadro.
    private func fittedRect(imageSize: CGSize?, in container: CGSize) -> CGRect {
        let aspect: CGFloat = {
            guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return 0.62 }
            return imageSize.width / imageSize.height
        }()
        var width = container.height * aspect
        var height = container.height
        if width > container.width {
            width = container.width
            height = width / aspect
        }
        return CGRect(x: (container.width - width) / 2,
                      y: (container.height - height) / 2,
                      width: width,
                      height: height)
    }
}

/// Ventana que aloja la interfaz SwiftUI de preferencias.
final class PreferencesWindowController: NSWindowController {

    convenience init(preferences: Preferences) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
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
