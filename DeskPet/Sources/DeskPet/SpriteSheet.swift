import AppKit
import CoreGraphics

/// Un sprite sheet troceado en filas de fotogramas.
///
/// Convención: la fila 0 (la de arriba) es la animación de reposo/colgado y la
/// fila 1, si existe, es la pirueta. Las filas siguientes se ignoran.
struct SpriteSheet {

    let frameRows: [[CGImage]]

    var idleFrames: [CGImage] { frameRows.first ?? [] }

    var trickFrames: [CGImage] {
        frameRows.count > 1 && !frameRows[1].isEmpty ? frameRows[1] : idleFrames
    }

    var isEmpty: Bool { idleFrames.isEmpty }

    /// Trocea un PNG en una rejilla filas × columnas.
    static func load(path: String, columns: Int, rows: Int) -> SpriteSheet? {
        guard columns > 0, rows > 0 else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded),
              let image = NSImage(contentsOfFile: expanded),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let tileWidth = cgImage.width / columns
        let tileHeight = cgImage.height / rows
        guard tileWidth > 0, tileHeight > 0 else { return nil }

        var frameRows: [[CGImage]] = []
        for row in 0..<rows {
            var frames: [CGImage] = []
            for column in 0..<columns {
                // CGImage.cropping usa píxeles con origen arriba-izquierda,
                // así que la fila 0 es la de arriba del PNG.
                let rect = CGRect(x: column * tileWidth,
                                  y: row * tileHeight,
                                  width: tileWidth,
                                  height: tileHeight)
                if let frame = cgImage.cropping(to: rect) {
                    frames.append(frame)
                }
            }
            if !frames.isEmpty { frameRows.append(frames) }
        }

        guard !frameRows.isEmpty else { return nil }
        return SpriteSheet(frameRows: frameRows)
    }
}

/// Entrega el sprite sheet en uso, con caché y respaldo programático.
enum SpriteProvider {

    private static var cacheKey: String?
    private static var cached: SpriteSheet?

    static func sheet(for preferences: Preferences) -> SpriteSheet {
        let key = "\(preferences.spriteSheetPath)|\(preferences.spriteColumnsValue)|\(preferences.spriteRowsValue)"
        if key == cacheKey, let cached { return cached }

        let sheet: SpriteSheet
        if !preferences.spriteSheetPath.isEmpty,
           let loaded = SpriteSheet.load(path: preferences.spriteSheetPath,
                                         columns: preferences.spriteColumnsValue,
                                         rows: preferences.spriteRowsValue),
           !loaded.isEmpty {
            sheet = loaded
        } else {
            if !preferences.spriteSheetPath.isEmpty {
                NSLog("DeskPet: no se pudo leer el sprite sheet en \(preferences.spriteSheetPath); uso los sprites generados.")
            }
            sheet = bundledSheet(columns: preferences.spriteColumnsValue,
                                 rows: preferences.spriteRowsValue)
        }

        cacheKey = key
        cached = sheet
        return sheet
    }

    static func invalidate() {
        cacheKey = nil
        cached = nil
    }

    /// Busca `pet_sheet.png` dentro del bundle; si no está, dibuja placeholders.
    private static func bundledSheet(columns: Int, rows: Int) -> SpriteSheet {
        if let url = Bundle.main.url(forResource: "pet_sheet", withExtension: "png"),
           let loaded = SpriteSheet.load(path: url.path, columns: columns, rows: rows),
           !loaded.isEmpty {
            return loaded
        }
        return PlaceholderSprites.makeSheet(columns: max(columns, 4), rows: max(rows, 2))
    }
}
