import AppKit
import QuartzCore

/// Medidas de la ventana de la mascota. Todo en coordenadas de CALayer
/// (origen abajo-izquierda, sin geometría invertida).
struct PetGeometry {

    let petSize: CGFloat

    /// Distancia entre el borde superior de la ventana y la parte alta del sprite.
    var dropDistance: CGFloat { petSize * 1.5 }

    /// Hueco extra por debajo para el rebote y el balanceo.
    var bottomPadding: CGFloat { petSize * 0.4 }

    var windowSize: CGSize {
        CGSize(width: petSize * 2, height: dropDistance + petSize + bottomPadding)
    }

    var centerX: CGFloat { windowSize.width / 2 }
    var topY: CGFloat { windowSize.height }

    /// Centro del sprite cuando está colgando en reposo.
    var restCenterY: CGFloat { windowSize.height - dropDistance - petSize / 2 }

    /// Centro del sprite cuando está escondido por encima del borde superior.
    var hiddenCenterY: CGFloat { windowSize.height + petSize }

    func petRect(centerY: CGFloat) -> CGRect {
        CGRect(x: centerX - petSize / 2, y: centerY - petSize / 2, width: petSize, height: petSize)
    }

    /// Hilo desde el borde superior hasta la parte alta del sprite.
    func webPath(petCenterY: CGFloat, bow: CGFloat) -> CGPath {
        let start = CGPoint(x: centerX, y: topY)
        let end = CGPoint(x: centerX, y: min(petCenterY + petSize * 0.42, topY))
        let control = CGPoint(x: centerX + bow, y: (start.y + end.y) / 2)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

/// Vista que aloja el árbol de capas de la mascota. No dibuja nada por sí misma.
final class PetHostView: NSView {

    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let root = CALayer()
        root.isOpaque = false
        root.backgroundColor = NSColor.clear.cgColor
        // Capa alojada: hay que asignarla antes de activar wantsLayer.
        self.layer = root
        self.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        layer?.sublayers?.forEach { applyScale(scale, to: $0) }
    }

    private func applyScale(_ scale: CGFloat, to layer: CALayer) {
        layer.contentsScale = scale
        layer.sublayers?.forEach { applyScale(scale, to: $0) }
    }
}

/// Máquina de animación: entrada, balanceo, pirueta y salida.
/// Nunca bloquea el hilo principal: todo son animaciones de Core Animation.
final class PetAnimator {

    private let preferences: Preferences
    private weak var hostView: PetHostView?

    private let swingLayer = CALayer()
    private let webLayer = CAShapeLayer()
    private let petLayer = CALayer()

    private var geometry = PetGeometry(petSize: 140)
    private var sheet = SpriteSheet(frameRows: [])
    private var generation = 0

    /// Duraciones del ciclo.
    static let entranceDuration: CFTimeInterval = 1.5
    static let exitDuration: CFTimeInterval = 1.0
    static let trickDuration: CFTimeInterval = 0.9

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Montaje

    func attach(to view: PetHostView) {
        hostView = view
        guard let root = view.layer else { return }
        if swingLayer.superlayer == nil {
            swingLayer.addSublayer(webLayer)
            swingLayer.addSublayer(petLayer)
            root.addSublayer(swingLayer)
        }

        webLayer.fillColor = nil
        webLayer.strokeColor = NSColor.white.withAlphaComponent(0.92).cgColor
        webLayer.lineCap = .round
        webLayer.shadowColor = NSColor.black.cgColor
        webLayer.shadowOpacity = 0.25
        webLayer.shadowRadius = 1.5
        webLayer.shadowOffset = CGSize(width: 0, height: -1)

        petLayer.contentsGravity = .resizeAspect
        petLayer.magnificationFilter = .nearest
        petLayer.minificationFilter = .trilinear
        petLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    /// Recalcula geometría y sprites. Deja la mascota fuera de pantalla.
    func prepare(geometry: PetGeometry) {
        self.geometry = geometry
        sheet = SpriteProvider.sheet(for: preferences)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        swingLayer.bounds = CGRect(origin: .zero, size: geometry.windowSize)
        swingLayer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        swingLayer.position = CGPoint(x: geometry.centerX, y: geometry.topY)
        swingLayer.transform = CATransform3DIdentity

        webLayer.frame = CGRect(origin: .zero, size: geometry.windowSize)
        webLayer.lineWidth = max(1.5, geometry.petSize * 0.014)

        petLayer.bounds = CGRect(x: 0, y: 0, width: geometry.petSize, height: geometry.petSize)
        petLayer.position = CGPoint(x: geometry.centerX, y: geometry.hiddenCenterY)
        petLayer.transform = CATransform3DIdentity
        if let firstFrame = sheet.idleFrames.first {
            petLayer.contents = firstFrame
            petLayer.backgroundColor = nil
        } else {
            // Último recurso: un bloque de color para que algo se vea.
            petLayer.contents = nil
            petLayer.backgroundColor = NSColor.systemRed.cgColor
            petLayer.cornerRadius = geometry.petSize * 0.15
        }
        webLayer.path = geometry.webPath(petCenterY: geometry.hiddenCenterY, bow: 0)

        CATransaction.commit()
    }

    /// Rectángulo que ocupa el sprite dentro de la vista (para el clic y la nota).
    var petRectInView: CGRect {
        geometry.petRect(centerY: geometry.restCenterY)
    }

    // MARK: - Fases

    func playEntrance(completion: @escaping () -> Void) {
        let token = generation
        let sampleCount = 60
        var positions: [CGPoint] = []
        var paths: [CGPath] = []

        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleCount - 1)
            let progress = index == sampleCount - 1 ? 1.0 : PetAnimator.dampedDrop(t)
            let y = geometry.hiddenCenterY + (geometry.restCenterY - geometry.hiddenCenterY) * CGFloat(progress)
            positions.append(CGPoint(x: geometry.centerX, y: y))
            let bow = CGFloat(sin(t * Double.pi) * (1 - t)) * geometry.petSize * 0.09
            paths.append(geometry.webPath(petCenterY: y, bow: bow))
        }

        startSpriteAnimation(frames: sheet.idleFrames, repeatForever: true)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.position = positions[positions.count - 1]
        webLayer.path = paths[paths.count - 1]
        CATransaction.commit()

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = positions.map { NSValue(point: $0) }
        positionAnimation.duration = PetAnimator.entranceDuration
        positionAnimation.calculationMode = .linear
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        let pathAnimation = CAKeyframeAnimation(keyPath: "path")
        pathAnimation.values = paths
        pathAnimation.duration = PetAnimator.entranceDuration
        pathAnimation.calculationMode = .linear
        pathAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            completion()
        }
        petLayer.add(positionAnimation, forKey: "phase.position")
        webLayer.add(pathAnimation, forKey: "phase.path")
        CATransaction.commit()
    }

    func startIdleSway() {
        let angle = 0.055 // ~3,2°
        let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        sway.values = [0, angle, 0, -angle, 0]
        sway.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        sway.duration = 3.2
        sway.repeatCount = .infinity
        sway.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        swingLayer.add(sway, forKey: "idle.sway")
    }

    func stopIdleSway() {
        swingLayer.removeAnimation(forKey: "idle.sway")
    }

    func playTrick(completion: @escaping () -> Void) {
        let token = generation
        startSpriteAnimation(frames: sheet.trickFrames, repeatForever: true)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = PetAnimator.trickDuration
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            self.startSpriteAnimation(frames: self.sheet.idleFrames, repeatForever: true)
            completion()
        }
        petLayer.add(spin, forKey: "phase.trick")
        CATransaction.commit()
    }

    func playExit(completion: @escaping () -> Void) {
        let token = generation
        let sampleCount = 40
        var positions: [CGPoint] = []
        var paths: [CGPath] = []

        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleCount - 1)
            let progress = t * t * t // easeIn: arranca despacio y acelera al subir
            let y = geometry.restCenterY + (geometry.hiddenCenterY - geometry.restCenterY) * CGFloat(progress)
            positions.append(CGPoint(x: geometry.centerX, y: y))
            paths.append(geometry.webPath(petCenterY: y, bow: 0))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.position = positions[positions.count - 1]
        webLayer.path = paths[paths.count - 1]
        CATransaction.commit()

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = positions.map { NSValue(point: $0) }
        positionAnimation.duration = PetAnimator.exitDuration
        positionAnimation.calculationMode = .linear

        let pathAnimation = CAKeyframeAnimation(keyPath: "path")
        pathAnimation.values = paths
        pathAnimation.duration = PetAnimator.exitDuration
        pathAnimation.calculationMode = .linear

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            completion()
        }
        petLayer.add(positionAnimation, forKey: "phase.position")
        webLayer.add(pathAnimation, forKey: "phase.path")
        CATransaction.commit()
    }

    /// Corta todo: sin animaciones vivas, consumo cero.
    func teardown() {
        generation &+= 1
        petLayer.removeAllAnimations()
        webLayer.removeAllAnimations()
        swingLayer.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        swingLayer.transform = CATransform3DIdentity
        petLayer.transform = CATransform3DIdentity
        petLayer.position = CGPoint(x: geometry.centerX, y: geometry.hiddenCenterY)
        webLayer.path = geometry.webPath(petCenterY: geometry.hiddenCenterY, bow: 0)
        CATransaction.commit()
    }

    // MARK: - Sprites

    private func startSpriteAnimation(frames: [CGImage], repeatForever: Bool) {
        guard frames.count > 1 else {
            if let single = frames.first {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                petLayer.contents = single
                CATransaction.commit()
            }
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames
        animation.calculationMode = .discrete
        animation.duration = Double(frames.count) / preferences.spriteFPSValue
        animation.repeatCount = repeatForever ? .infinity : 1
        petLayer.add(animation, forKey: "sprite")
    }

    /// Caída con easing y pequeño rebote elástico al final.
    private static func dampedDrop(_ t: Double) -> Double {
        1 - exp(-6 * t) * cos(10 * t)
    }
}
