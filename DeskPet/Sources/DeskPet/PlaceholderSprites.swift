import AppKit
import CoreGraphics

/// Sprites dibujados por código para que la app funcione sin PNG externo.
/// Fila 0: colgado en reposo. Fila 1: pirueta (cuerpo recogido).
enum PlaceholderSprites {

    static func makeSheet(columns: Int, rows: Int, tile: Int = 128) -> SpriteSheet {
        var frameRows: [[CGImage]] = []
        for row in 0..<max(rows, 1) {
            var frames: [CGImage] = []
            for column in 0..<max(columns, 1) {
                let phase = Double(column) / Double(max(columns, 1))
                if let image = makeFrame(phase: phase, tucked: row == 1, tile: tile) {
                    frames.append(image)
                }
            }
            if !frames.isEmpty { frameRows.append(frames) }
        }
        return SpriteSheet(frameRows: frameRows)
    }

    // MARK: - Dibujo de un fotograma

    private static func makeFrame(phase: Double, tucked: Bool, tile: Int) -> CGImage? {
        guard let context = CGContext(data: nil,
                                      width: tile,
                                      height: tile,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        let size = CGFloat(tile)
        let wave = CGFloat(sin(phase * 2 * Double.pi))
        let unit = size / 128.0

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.interpolationQuality = .high

        let red = CGColor(red: 0.85, green: 0.13, blue: 0.17, alpha: 1)
        let blue = CGColor(red: 0.10, green: 0.20, blue: 0.55, alpha: 1)
        let ink = CGColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1)
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * size, y: y * size)
        }

        func stroke(_ points: [CGPoint], color: CGColor, width: CGFloat) {
            guard points.count > 1 else { return }
            context.setStrokeColor(color)
            context.setLineWidth(width * unit)
            context.move(to: points[0])
            for next in points.dropFirst() { context.addLine(to: next) }
            context.strokePath()
        }

        // Brazos hacia el hilo (arriba del todo).
        let grip = point(0.5, 0.95)
        stroke([point(0.40, 0.70), point(0.42 + 0.02 * wave, 0.84), grip], color: red, width: 7)
        stroke([point(0.60, 0.70), point(0.58 + 0.02 * wave, 0.84), grip], color: red, width: 7)

        // Torso.
        context.setFillColor(red)
        let torso = CGRect(x: 0.38 * size, y: 0.38 * size, width: 0.24 * size, height: 0.30 * size)
        context.addPath(CGPath(roundedRect: torso,
                               cornerWidth: 0.06 * size,
                               cornerHeight: 0.06 * size,
                               transform: nil))
        context.fillPath()

        // Piernas: colgando o recogidas durante la pirueta.
        if tucked {
            let lift = 0.04 * CGFloat(1 + wave)
            stroke([point(0.44, 0.40), point(0.34, 0.34 + lift), point(0.42, 0.28 + lift)],
                   color: blue, width: 8)
            stroke([point(0.56, 0.40), point(0.66, 0.34 + lift), point(0.58, 0.28 + lift)],
                   color: blue, width: 8)
        } else {
            let swing = 0.05 * wave
            stroke([point(0.45, 0.40), point(0.43 + swing, 0.26), point(0.41 + swing * 1.4, 0.13)],
                   color: blue, width: 8)
            stroke([point(0.55, 0.40), point(0.57 + swing, 0.26), point(0.59 + swing * 1.4, 0.13)],
                   color: blue, width: 8)
            // Pies.
            context.setFillColor(blue)
            context.fillEllipse(in: CGRect(x: (0.37 + swing * 1.4) * size, y: 0.09 * size,
                                           width: 0.09 * size, height: 0.06 * size))
            context.fillEllipse(in: CGRect(x: (0.55 + swing * 1.4) * size, y: 0.09 * size,
                                           width: 0.09 * size, height: 0.06 * size))
        }

        // Cabeza.
        let headRect = CGRect(x: 0.34 * size, y: 0.60 * size, width: 0.32 * size, height: 0.30 * size)
        context.setFillColor(red)
        context.fillEllipse(in: headRect)

        // Telaraña de la máscara.
        context.setStrokeColor(ink)
        context.setLineWidth(1.2 * unit)
        context.strokeEllipse(in: headRect.insetBy(dx: 0.05 * size, dy: 0.05 * size))
        stroke([point(0.50, 0.60), point(0.50, 0.90)], color: ink, width: 1.2)
        stroke([point(0.36, 0.75), point(0.64, 0.75)], color: ink, width: 1.2)

        // Ojos.
        context.setFillColor(white)
        context.fillEllipse(in: CGRect(x: 0.375 * size, y: 0.70 * size,
                                       width: 0.10 * size, height: 0.075 * size))
        context.fillEllipse(in: CGRect(x: 0.525 * size, y: 0.70 * size,
                                       width: 0.10 * size, height: 0.075 * size))
        context.setStrokeColor(ink)
        context.setLineWidth(1.4 * unit)
        context.strokeEllipse(in: CGRect(x: 0.375 * size, y: 0.70 * size,
                                         width: 0.10 * size, height: 0.075 * size))
        context.strokeEllipse(in: CGRect(x: 0.525 * size, y: 0.70 * size,
                                         width: 0.10 * size, height: 0.075 * size))

        // Emblema de araña en el pecho.
        context.setFillColor(ink)
        context.fillEllipse(in: CGRect(x: 0.475 * size, y: 0.53 * size,
                                       width: 0.05 * size, height: 0.05 * size))
        stroke([point(0.44, 0.58), point(0.50, 0.555), point(0.56, 0.58)], color: ink, width: 1.2)
        stroke([point(0.44, 0.50), point(0.50, 0.525), point(0.56, 0.50)], color: ink, width: 1.2)

        return context.makeImage()
    }
}
