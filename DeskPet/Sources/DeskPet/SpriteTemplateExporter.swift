import AppKit
import CoreGraphics

/// Exporta los sprites generados por código como PNG, para usarlo de plantilla
/// al dibujar los tuyos con las medidas exactas que espera la app.
enum SpriteTemplateExporter {

    static func makeSheetImage(columns: Int, rows: Int, tile: Int = 128) -> CGImage? {
        let sheet = PlaceholderSprites.makeSheet(columns: columns, rows: rows, tile: tile)
        guard !sheet.isEmpty else { return nil }

        let width = columns * tile
        let height = rows * tile
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        for (rowIndex, frames) in sheet.frameRows.enumerated() {
            for (columnIndex, frame) in frames.enumerated() {
                // La fila 0 va arriba del PNG; CGContext tiene el origen abajo.
                let rect = CGRect(x: columnIndex * tile,
                                  y: (rows - 1 - rowIndex) * tile,
                                  width: tile,
                                  height: tile)
                context.draw(frame, in: rect)
            }
        }
        return context.makeImage()
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        representation.size = NSSize(width: image.width, height: image.height)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "DeskPet", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo codificar el PNG."
            ])
        }
        try data.write(to: url)
    }

    /// Abre un panel de guardado y escribe la plantilla.
    static func exportInteractively(preferences: Preferences) {
        let columns = max(preferences.spriteColumnsValue, 4)
        let rows = max(preferences.spriteRowsValue, 2)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "deskpet_sprite_template_\(columns)x\(rows).png"
        panel.message = "Guarda la plantilla de sprites (\(columns) columnas × \(rows) filas, 128 px por casilla)"
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = makeSheetImage(columns: columns, rows: rows) else { return }

        do {
            try writePNG(image, to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "No se pudo guardar la plantilla"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
