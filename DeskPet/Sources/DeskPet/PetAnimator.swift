import AppKit
import QuartzCore

/// Medidas de la ventana de la mascota, en coordenadas de CALayer
/// (origen abajo-izquierda, sin geometría invertida).
///
/// El "grip" es el punto donde las manos agarran el hilo: coincide con el
/// `anchorPoint` de la capa, así que `petLayer.position` **es** ese punto y el
/// hilo siempre acaba exactamente ahí.
struct PetGeometry {

    /// Tamaño de la ilustración en puntos.
    let artSize: CGSize
    /// Punto de agarre en espacio unitario del layer (y = 1 es arriba).
    let anchor: CGPoint

    private let padding: CGFloat = 14

    /// Distancia del anclaje a la esquina más lejana: el radio que barre la
    /// ilustración al girar 360°. La ventana tiene que dar cabida a ese círculo
    /// o la pirueta se vería recortada.
    var radius: CGFloat {
        let anchorX = anchor.x * artSize.width
        let anchorY = anchor.y * artSize.height
        let horizontal = [anchorX, artSize.width - anchorX]
        let vertical = [anchorY, artSize.height - anchorY]
        var best: CGFloat = 0
        for dx in horizontal {
            for dy in vertical {
                best = max(best, sqrt(dx * dx + dy * dy))
            }
        }
        return max(best, 1)
    }

    /// Cuánto baja el grip desde el borde superior de la ventana.
    var dropDistance: CGFloat {
        max(artSize.height * 1.15, radius + padding)
    }

    var windowSize: CGSize {
        CGSize(width: 2 * (radius + padding),
               height: dropDistance + radius + padding)
    }

    var centerX: CGFloat { windowSize.width / 2 }
    var topY: CGFloat { windowSize.height }

    /// Grip en reposo (colgando).
    var gripRest: CGPoint { CGPoint(x: centerX, y: topY - dropDistance) }

    /// Grip fuera de pantalla, por encima del borde superior.
    var gripHidden: CGPoint { CGPoint(x: centerX, y: topY + radius + padding) }

    /// Rectángulo que ocupa la ilustración para un grip dado (sin rotación).
    func petRect(grip: CGPoint) -> CGRect {
        CGRect(x: grip.x - anchor.x * artSize.width,
               y: grip.y - anchor.y * artSize.height,
               width: artSize.width,
               height: artSize.height)
    }

    /// Hilo desde el borde superior hasta el grip, curvado según `bow`.
    func webPath(to grip: CGPoint, bow: CGFloat) -> CGPath {
        let start = CGPoint(x: centerX, y: topY)
        let end = CGPoint(x: grip.x, y: min(grip.y, topY))
        let control = CGPoint(x: (start.x + end.x) / 2 + bow, y: (start.y + end.y) / 2)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

/// Vista que aloja el árbol de capas de la mascota. No dibuja nada por sí misma.
final class PetHostView: NSView {

    var onClick: (() -> Void)?
    var onBackingChange: (() -> Void)?

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
        onBackingChange?()
    }
}

/// Máquina de animación: entrada, balanceo, pirueta y salida.
///
/// No hay sprite sheet ni fotogramas: una sola ilustración en un CALayer y
/// transformaciones (position, rotation.z, scale) sobre su punto de anclaje.
final class PetAnimator {

    private let preferences: Preferences

    private let webLayer = CAShapeLayer()
    /// Contenedor con el anchorPoint en las manos: sobre él pivota todo.
    private let petLayer = CALayer()
    private let normalLayer = CALayer()
    private let tuckedLayer = CALayer()

    private var geometry = PetGeometry(artSize: CGSize(width: 136, height: 220),
                                       anchor: CGPoint(x: 0.5, y: 1))
    private var artwork: PetArtwork?
    private var generation = 0

    static let entranceDuration: CFTimeInterval = 1.5
    static let exitDuration: CFTimeInterval = 1.2
    static let trickDuration: CFTimeInterval = 1.2
    static let swayDuration: CFTimeInterval = 2.5

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Montaje

    func attach(to view: PetHostView) {
        guard let root = view.layer else { return }
        if petLayer.superlayer == nil {
            petLayer.addSublayer(normalLayer)
            petLayer.addSublayer(tuckedLayer)
            root.addSublayer(webLayer)
            root.addSublayer(petLayer)
        }

        webLayer.fillColor = nil
        webLayer.strokeColor = NSColor.white.withAlphaComponent(0.92).cgColor
        webLayer.lineCap = .round
        webLayer.shadowColor = NSColor.black.cgColor
        webLayer.shadowOpacity = 0.25
        webLayer.shadowRadius = 1.5
        webLayer.shadowOffset = CGSize(width: 0, height: -1)
        webLayer.strokeEnd = 0

        for layer in [normalLayer, tuckedLayer] {
            layer.contentsGravity = .resizeAspect
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        tuckedLayer.opacity = 0
    }

    /// Carga la ilustración a la escala de la pantalla y devuelve la geometría
    /// resultante. Hay que llamarlo antes de dimensionar la ventana.
    func prepareArtwork(scale: CGFloat) -> PetGeometry {
        let loaded = ArtworkProvider.artwork(for: preferences, scale: scale)
        artwork = loaded
        geometry = PetGeometry(artSize: loaded.pointSize,
                               anchor: preferences.anchorPointValue)
        return geometry
    }

    /// Coloca las capas según la geometría, con la mascota fuera de pantalla.
    func applyGeometry(_ geometry: PetGeometry) {
        self.geometry = geometry

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        webLayer.frame = CGRect(origin: .zero, size: geometry.windowSize)
        webLayer.lineWidth = max(1.5, geometry.artSize.height * 0.011)
        webLayer.path = geometry.webPath(to: geometry.gripRest, bow: 0)
        webLayer.strokeEnd = 0

        petLayer.bounds = CGRect(origin: .zero, size: geometry.artSize)
        petLayer.anchorPoint = geometry.anchor
        petLayer.position = geometry.gripHidden
        petLayer.transform = CATransform3DIdentity

        let artBounds = CGRect(origin: .zero, size: geometry.artSize)
        for layer in [normalLayer, tuckedLayer] {
            layer.bounds = artBounds
            layer.position = CGPoint(x: geometry.artSize.width / 2, y: geometry.artSize.height / 2)
            layer.contentsScale = artwork?.scale ?? 2
        }
        normalLayer.contents = artwork?.normal
        normalLayer.opacity = 1
        tuckedLayer.contents = artwork?.tucked
        tuckedLayer.opacity = 0

        if artwork?.normal == nil {
            // Sin bitmap: al menos que se vea algo.
            normalLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(0.8).cgColor
            normalLayer.cornerRadius = geometry.artSize.width * 0.15
        } else {
            normalLayer.backgroundColor = nil
        }

        CATransaction.commit()
    }

    /// Vuelve a rasterizar el arte (cambio de pantalla o de ajustes) sin tocar
    /// las animaciones en curso.
    func refreshArtwork(scale: CGFloat) {
        let loaded = ArtworkProvider.artwork(for: preferences, scale: scale)
        artwork = loaded
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        normalLayer.contents = loaded.normal
        tuckedLayer.contents = loaded.tucked
        normalLayer.contentsScale = loaded.scale
        tuckedLayer.contentsScale = loaded.scale
        CATransaction.commit()
    }

    /// Coloca la mascota colgando en reposo, sin animación. Se usa al aplicar
    /// ajustes en vivo mientras ya está en pantalla.
    func settleAtRest() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.position = geometry.gripRest
        petLayer.transform = CATransform3DIdentity
        webLayer.path = geometry.webPath(to: geometry.gripRest, bow: 0)
        webLayer.strokeEnd = 1
        CATransaction.commit()
    }

    /// Rectángulo de la ilustración en reposo (clic y anclaje de la nota).
    var petRectInView: CGRect {
        geometry.petRect(grip: geometry.gripRest)
    }

    // MARK: - Bajada

    func playEntrance(completion: @escaping () -> Void) {
        let token = generation
        let sampleCount = 60

        let hiddenY = geometry.gripHidden.y
        let restY = geometry.gripRest.y
        // El rebote se mide en puntos, no como fracción del recorrido: la
        // mascota arranca muy por encima del borde y un porcentaje del trayecto
        // daría un sobreimpulso descomunal.
        let bouncePoints = geometry.artSize.height * 0.09

        var positions: [CGPoint] = []
        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleCount - 1)
            let spring = index == sampleCount - 1 ? 1 : PetAnimator.dampedDrop(t)
            let settle = CGFloat(min(spring, 1))
            let overshoot = CGFloat(max(spring - 1, 0) / PetAnimator.maxDropOvershoot)
            let y = hiddenY + (restY - hiddenY) * settle - bouncePoints * overshoot
            positions.append(CGPoint(x: geometry.centerX, y: y))
        }

        let deepestY = positions.map { $0.y }.min() ?? restY
        let fullLength = max(geometry.topY - deepestY, 1)
        let strokeEnds = positions.map { PetAnimator.clamp((geometry.topY - $0.y) / fullLength) }
        let entrancePath = geometry.webPath(to: CGPoint(x: geometry.centerX, y: deepestY), bow: 0)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        webLayer.path = entrancePath
        webLayer.strokeEnd = PetAnimator.clamp((geometry.topY - restY) / fullLength)
        petLayer.position = geometry.gripRest
        CATransaction.commit()

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = positions.map { NSValue(point: $0) }
        positionAnimation.duration = PetAnimator.entranceDuration
        positionAnimation.calculationMode = .linear
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        let strokeAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
        strokeAnimation.values = strokeEnds
        strokeAnimation.duration = PetAnimator.entranceDuration
        strokeAnimation.calculationMode = .linear
        strokeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            completion()
        }
        petLayer.add(positionAnimation, forKey: "phase.position")
        webLayer.add(strokeAnimation, forKey: "phase.stroke")
        CATransaction.commit()
    }

    // MARK: - Balanceo

    func startIdleSway() {
        let amplitude = preferences.swingAmplitudeRadians
        let bow = sin(amplitude) * geometry.dropDistance * 0.30

        // El hilo pasa a medir exactamente hasta el grip: mismo aspecto, pero
        // ahora strokeEnd = 1 y lo que se anima es la curvatura.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        webLayer.path = geometry.webPath(to: geometry.gripRest, bow: 0)
        webLayer.strokeEnd = 1
        CATransaction.commit()

        // Desfase aleatorio: dos apariciones seguidas no arrancan igual.
        let phase = Double.random(in: 0..<(PetAnimator.swayDuration * 2))

        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -amplitude
        sway.toValue = amplitude
        sway.duration = PetAnimator.swayDuration
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sway.timeOffset = phase
        petLayer.add(sway, forKey: "idle.sway")

        // El hilo se curva en fase con el giro para acompañar al personaje.
        let webSway = CABasicAnimation(keyPath: "path")
        webSway.fromValue = geometry.webPath(to: geometry.gripRest, bow: -bow)
        webSway.toValue = geometry.webPath(to: geometry.gripRest, bow: bow)
        webSway.duration = PetAnimator.swayDuration
        webSway.autoreverses = true
        webSway.repeatCount = .infinity
        webSway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        webSway.timeOffset = phase
        webLayer.add(webSway, forKey: "idle.web")
    }

    func stopIdleSway() {
        petLayer.removeAnimation(forKey: "idle.sway")
        webLayer.removeAnimation(forKey: "idle.web")
    }

    // MARK: - Pirueta

    func playTrick(completion: @escaping () -> Void) {
        let token = generation

        // Aditiva: se suma al balanceo, que sigue corriendo por debajo, así que
        // ni al empezar ni al acabar hay saltos.
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.isAdditive = true
        spin.duration = PetAnimator.trickDuration
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let squash = CAKeyframeAnimation(keyPath: "transform.scale")
        squash.values = [1.0, 0.92, 0.92, 1.0]
        squash.keyTimes = [0, 0.25, 0.75, 1]
        squash.duration = PetAnimator.trickDuration
        squash.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            completion()
        }
        petLayer.add(spin, forKey: "trick.spin")
        petLayer.add(squash, forKey: "trick.scale")

        // Crossfade a la pose recogida, si la hay.
        if artwork?.tucked != nil {
            let fadeOut = CAKeyframeAnimation(keyPath: "opacity")
            fadeOut.values = [1.0, 0.0, 0.0, 1.0]
            fadeOut.keyTimes = [0, 0.2, 0.8, 1]
            fadeOut.duration = PetAnimator.trickDuration

            let fadeIn = CAKeyframeAnimation(keyPath: "opacity")
            fadeIn.values = [0.0, 1.0, 1.0, 0.0]
            fadeIn.keyTimes = [0, 0.2, 0.8, 1]
            fadeIn.duration = PetAnimator.trickDuration

            normalLayer.add(fadeOut, forKey: "trick.fade")
            tuckedLayer.add(fadeIn, forKey: "trick.fade")
        }
        CATransaction.commit()
    }

    // MARK: - Subida

    func playExit(completion: @escaping () -> Void) {
        let token = generation
        let sampleCount = 40

        // Se congela el estado visible actual para que quitar el balanceo no
        // provoque ningún salto.
        let currentRotation = (petLayer.presentation()?.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.doubleValue ?? 0
        let currentPath = webLayer.presentation()?.path ?? webLayer.path
        stopIdleSway()

        let restY = geometry.gripRest.y
        let hiddenY = geometry.gripHidden.y
        let restPath = geometry.webPath(to: geometry.gripRest, bow: 0)
        let fullLength = max(geometry.topY - restY, 1)

        var positions: [CGPoint] = []
        var strokeEnds: [CGFloat] = []
        for index in 0..<sampleCount {
            let t = CGFloat(index) / CGFloat(sampleCount - 1)
            let progress = t * t * t   // easeIn: arranca despacio y acelera
            let y = restY + (hiddenY - restY) * progress
            positions.append(CGPoint(x: geometry.centerX, y: y))
            strokeEnds.append(PetAnimator.clamp((geometry.topY - y) / fullLength))
        }

        // El modelo ya está sin rotación (el balanceo era una animación
        // explícita); la continuidad visual la da el fromValue de `upright`,
        // añadido en este mismo turno del runloop, así que no hay salto.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.position = geometry.gripHidden
        webLayer.path = restPath
        webLayer.strokeEnd = 0
        CATransaction.commit()

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = positions.map { NSValue(point: $0) }
        positionAnimation.duration = PetAnimator.exitDuration
        positionAnimation.calculationMode = .linear

        let strokeAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
        strokeAnimation.values = strokeEnds
        strokeAnimation.duration = PetAnimator.exitDuration
        strokeAnimation.calculationMode = .linear

        // El hilo se endereza mientras se retrae.
        let straighten = CABasicAnimation(keyPath: "path")
        straighten.fromValue = currentPath
        straighten.toValue = restPath
        straighten.duration = PetAnimator.exitDuration * 0.45
        straighten.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Y el personaje se endereza al subir.
        let upright = CABasicAnimation(keyPath: "transform.rotation.z")
        upright.fromValue = currentRotation
        upright.toValue = 0
        upright.duration = PetAnimator.exitDuration * 0.6
        upright.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == token else { return }
            completion()
        }
        petLayer.add(positionAnimation, forKey: "phase.position")
        petLayer.add(upright, forKey: "phase.upright")
        webLayer.add(strokeAnimation, forKey: "phase.stroke")
        webLayer.add(straighten, forKey: "phase.path")
        CATransaction.commit()
    }

    /// Corta todo: sin animaciones vivas, consumo cero.
    func teardown() {
        generation &+= 1
        petLayer.removeAllAnimations()
        webLayer.removeAllAnimations()
        normalLayer.removeAllAnimations()
        tuckedLayer.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayer.transform = CATransform3DIdentity
        petLayer.position = geometry.gripHidden
        normalLayer.opacity = 1
        tuckedLayer.opacity = 0
        webLayer.path = geometry.webPath(to: geometry.gripRest, bow: 0)
        webLayer.strokeEnd = 0
        CATransaction.commit()
    }

    // MARK: - Curvas

    /// Caída con easing y rebote elástico al final (muelle amortiguado).
    /// Vale 0 en t=0, pasa de 1 (sobreimpulso) y se asienta en 1.
    private static func dampedDrop(_ t: Double) -> Double {
        1 - exp(-6 * t) * cos(10 * t)
    }

    /// Sobreimpulso máximo de la curva anterior, para normalizar el rebote.
    private static let maxDropOvershoot: Double = {
        var best = 0.0
        for step in 0...400 {
            best = max(best, dampedDrop(Double(step) / 400) - 1)
        }
        return max(best, 0.0001)
    }()

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
