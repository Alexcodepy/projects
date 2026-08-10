import AppKit

/// Vista de la nota con estética pixel-art.
final class ReminderNoteView: NSView {

    var message: String = "" {
        didSet { needsDisplay = true }
    }

    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 16
    static let titleBlock: CGFloat = 22
    static let shadowOffset: CGFloat = 5

    private static let paper = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1)
    private static let ink = NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.13, alpha: 1)
    private static let accent = NSColor(calibratedRed: 0.78, green: 0.14, blue: 0.16, alpha: 1)

    static func titleFont() -> NSFont {
        NSFont(name: "Menlo-Bold", size: 10) ?? NSFont.boldSystemFont(ofSize: 10)
    }

    static func messageFont() -> NSFont {
        NSFont(name: "Menlo-Bold", size: 15) ?? NSFont.boldSystemFont(ofSize: 15)
    }

    static func messageAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        return [
            .font: messageFont(),
            .foregroundColor: ink,
            .paragraphStyle: paragraph
        ]
    }

    /// Tamaño de la nota para un mensaje dado.
    static func fittingSize(for message: String, maxWidth: CGFloat = 300) -> NSSize {
        let textWidth = maxWidth - horizontalPadding * 2
        let attributed = NSAttributedString(string: message, attributes: messageAttributes())
        let bounds = attributed.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = ceil(bounds.height) + verticalPadding * 2 + titleBlock + shadowOffset
        return NSSize(width: maxWidth + shadowOffset, height: max(height, 92))
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let body = NSRect(x: 0,
                          y: 0,
                          width: bounds.width - ReminderNoteView.shadowOffset,
                          height: bounds.height - ReminderNoteView.shadowOffset)

        // Sombra dura desplazada (aire de pixel-art).
        ReminderNoteView.ink.withAlphaComponent(0.85).setFill()
        NSBezierPath(rect: body.offsetBy(dx: ReminderNoteView.shadowOffset,
                                         dy: ReminderNoteView.shadowOffset)).fill()

        // Papel + borde de esquinas marcadas.
        ReminderNoteView.paper.setFill()
        NSBezierPath(rect: body).fill()

        ReminderNoteView.ink.setStroke()
        let border = NSBezierPath(rect: body.insetBy(dx: 1.5, dy: 1.5))
        border.lineWidth = 3
        border.stroke()

        let innerLine = NSBezierPath(rect: body.insetBy(dx: 6, dy: 6))
        innerLine.lineWidth = 1
        ReminderNoteView.ink.withAlphaComponent(0.35).setStroke()
        innerLine.stroke()

        // Cuadraditos en las esquinas.
        ReminderNoteView.ink.setFill()
        let block: CGFloat = 5
        for corner in [
            NSPoint(x: body.minX, y: body.minY),
            NSPoint(x: body.maxX - block, y: body.minY),
            NSPoint(x: body.minX, y: body.maxY - block),
            NSPoint(x: body.maxX - block, y: body.maxY - block)
        ] {
            NSBezierPath(rect: NSRect(x: corner.x, y: corner.y, width: block, height: block)).fill()
        }

        // Título.
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: ReminderNoteView.titleFont(),
            .foregroundColor: ReminderNoteView.accent,
            .kern: 2.5
        ]
        NSAttributedString(string: "REMINDER", attributes: titleAttributes).draw(
            at: NSPoint(x: ReminderNoteView.horizontalPadding,
                        y: ReminderNoteView.verticalPadding - 2)
        )

        // Mensaje.
        let textRect = NSRect(
            x: ReminderNoteView.horizontalPadding,
            y: ReminderNoteView.verticalPadding + ReminderNoteView.titleBlock - 4,
            width: body.width - ReminderNoteView.horizontalPadding * 2,
            height: body.height - ReminderNoteView.verticalPadding * 2 - ReminderNoteView.titleBlock + 4
        )
        NSAttributedString(string: message, attributes: ReminderNoteView.messageAttributes())
            .draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

/// Panel independiente para la nota de recordatorio, con fundidos.
final class ReminderController {

    static let fadeDuration: TimeInterval = 0.35

    private let preferences: Preferences
    private let panel: NSPanel
    private let noteView: ReminderNoteView
    private var isVisible = false

    init(preferences: Preferences) {
        self.preferences = preferences

        let initialRect = NSRect(x: 0, y: 0, width: 305, height: 100)
        noteView = ReminderNoteView(frame: initialRect)
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
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = noteView
        panel.alphaValue = 0
    }

    /// Coloca la nota a la izquierda de la mascota y la funde a la vista.
    func show(message: String, anchoredTo petRect: CGRect, on screen: NSScreen) {
        noteView.message = message

        let size = ReminderNoteView.fittingSize(for: message)
        let visible = screen.visibleFrame

        var origin = NSPoint(
            x: petRect.minX - size.width - 10,
            y: petRect.midY - size.height / 2
        )
        if origin.x < visible.minX + 8 {
            // Sin sitio a la izquierda: debajo de la mascota.
            origin.x = min(max(petRect.midX - size.width / 2, visible.minX + 8),
                           visible.maxX - size.width - 8)
            origin.y = petRect.minY - size.height - 12
        }
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)

        noteView.frame = NSRect(origin: .zero, size: size)
        noteView.needsDisplay = true
        panel.setFrame(NSRect(origin: origin, size: size), display: false)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        isVisible = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ReminderController.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = ReminderController.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return }
            self.panel.orderOut(nil)
        })
    }

    func hideImmediately() {
        isVisible = false
        panel.alphaValue = 0
        panel.orderOut(nil)
    }
}
