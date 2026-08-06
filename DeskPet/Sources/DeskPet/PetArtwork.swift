import AppKit
import CoreGraphics

/// Ilustración de la mascota ya rasterizada al tamaño y a la escala de la
/// pantalla actual. No hay fotogramas: la animación son transformaciones.
struct PetArtwork {

    /// Pose normal (colgando del hilo). Nil solo si falla el bitmap de respaldo.
    let normal: CGImage?
    /// Pose recogida para la pirueta. Opcional.
    let tucked: CGImage?
    /// Tamaño en puntos (la altura es la configurada en Preferencias).
    let pointSize: CGSize
    /// Escala de pantalla con la que se rasterizó (1x, 2x…).
    let scale: CGFloat

    var hasTuckedPose: Bool { tucked != nil }
}

/// Carga, rasteriza y cachea la ilustración.
enum ArtworkProvider {

    private static var cacheKey: String?
    private static var cached: PetArtwork?

    /// Formatos que se intentan cargar. PDF escala sin pérdida.
    static let supportedExtensions = ["pdf", "png", "svg", "tiff", "heic", "jpg", "jpeg"]

    static func artwork(for preferences: Preferences, scale: CGFloat) -> PetArtwork {
        let height = preferences.petHeightValue
        let key = [
            preferences.artworkPath,
            preferences.trickArtworkPath,
            String(format: "%.1f", height),
            String(format: "%.2f", scale)
        ].joined(separator: "|")

        if key == cacheKey, let cached { return cached }

        let artwork = build(preferences: preferences, height: height, scale: scale)
        cacheKey = key
        cached = artwork
        return artwork
    }

    static func invalidate() {
        cacheKey = nil
        cached = nil
    }

    /// Carga la imagen sin rasterizar (para la vista previa de Preferencias).
    static func loadImage(path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return nil }
        return NSImage(contentsOfFile: expanded)
    }

    // MARK: - Construcción

    /// Orden de búsqueda: ruta de Preferencias → imagen del bundle → silueta.
    private static func build(preferences: Preferences, height: CGFloat, scale: CGFloat) -> PetArtwork {
        let normalImage = loadImage(path: preferences.artworkPath) ?? bundledImage(named: "pet")

        guard let normalImage,
              let rendered = rasterize(normalImage, height: height, scale: scale) else {
            if !preferences.artworkPath.isEmpty {
                NSLog("DeskPet: no se pudo cargar la ilustración en \(preferences.artworkPath); uso la silueta de respaldo.")
            }
            return placeholder(height: height, scale: scale)
        }

        let trickImage = loadImage(path: preferences.trickArtworkPath) ?? bundledImage(named: "pet_trick")
        let tucked = trickImage.flatMap { rasterize($0, height: height, scale: scale)?.image }

        return PetArtwork(normal: rendered.image,
                          tucked: tucked,
                          pointSize: rendered.pointSize,
                          scale: scale)
    }

    /// Ilustración empotrada en el bundle (Contents/Resources/pet.pdf, …).
    private static func bundledImage(named name: String) -> NSImage? {
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    /// Dibuja la imagen (PNG, PDF vectorial, …) en un bitmap del tamaño exacto
    /// que necesita la pantalla: nítido en Retina y sin pérdida en vectoriales.
    static func rasterize(_ image: NSImage, height: CGFloat, scale: CGFloat) -> (image: CGImage, pointSize: CGSize)? {
        let source = image.size
        guard source.width > 0, source.height > 0, height > 0, scale > 0 else { return nil }

        let aspect = source.width / source.height
        let pointSize = CGSize(width: max(1, (height * aspect).rounded()), height: height)
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded()))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded()))

        guard let context = CGContext(data: nil,
                                      width: pixelWidth,
                                      height: pixelHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(pixelWidth), height: CGFloat(pixelHeight)),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let rendered = context.makeImage() else { return nil }
        return (rendered, pointSize)
    }

    // MARK: - Silueta de respaldo

    /// Una única silueta dibujada con CoreGraphics para que la app arranque y
    /// anime aunque no haya arte. Manos arriba del todo, cuerpo colgando.
    static func placeholder(height: CGFloat, scale: CGFloat) -> PetArtwork {
        let aspect: CGFloat = 0.62
        let pointSize = CGSize(width: (height * aspect).rounded(), height: height)
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded()))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded()))

        let context = CGContext(data: nil,
                                width: pixelWidth,
                                height: pixelHeight,
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let image = context.flatMap {
            drawSilhouette(in: $0, width: CGFloat(pixelWidth), height: CGFloat(pixelHeight))
        }
        return PetArtwork(normal: image, tucked: nil, pointSize: pointSize, scale: scale)
    }

    private static func drawSilhouette(in context: CGContext, width: CGFloat, height: CGFloat) -> CGImage? {
        let body = CGColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1)
        let rim = CGColor(red: 1, green: 1, blue: 1, alpha: 0.45)
        let lineWidth = height * 0.012

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * width, y: y * height)
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Brazos: de las manos (arriba del todo) a los hombros.
        context.setStrokeColor(body)
        context.setLineWidth(height * 0.055)
        context.move(to: point(0.50, 0.96))
        context.addLine(to: point(0.30, 0.80))
        context.move(to: point(0.50, 0.96))
        context.addLine(to: point(0.70, 0.80))
        context.strokePath()

        // Manos agarrando el hilo: justo en el punto de anclaje por defecto.
        context.setFillColor(body)
        context.fillEllipse(in: CGRect(x: 0.42 * width, y: 0.925 * height,
                                       width: 0.16 * width, height: 0.055 * height))

        // Torso.
        let torso = CGRect(x: 0.31 * width, y: 0.36 * height,
                           width: 0.38 * width, height: 0.34 * height)
        context.addPath(CGPath(roundedRect: torso,
                               cornerWidth: 0.16 * width,
                               cornerHeight: 0.06 * height,
                               transform: nil))
        context.fillPath()

        // Cabeza.
        context.fillEllipse(in: CGRect(x: 0.34 * width, y: 0.66 * height,
                                       width: 0.32 * width, height: 0.17 * height))

        // Piernas.
        context.setStrokeColor(body)
        context.setLineWidth(height * 0.062)
        context.move(to: point(0.42, 0.40))
        context.addLine(to: point(0.38, 0.22))
        context.addLine(to: point(0.34, 0.06))
        context.move(to: point(0.58, 0.40))
        context.addLine(to: point(0.62, 0.22))
        context.addLine(to: point(0.66, 0.06))
        context.strokePath()

        // Borde claro para que la silueta se lea sobre fondos oscuros.
        context.setStrokeColor(rim)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(x: 0.34 * width, y: 0.66 * height,
                                         width: 0.32 * width, height: 0.17 * height))
        context.addPath(CGPath(roundedRect: torso,
                               cornerWidth: 0.16 * width,
                               cornerHeight: 0.06 * height,
                               transform: nil))
        context.strokePath()

        return context.makeImage()
    }
}
