import AppKit
import QuartzCore

@MainActor
public final class DesktopEffectView: NSView {
    private enum Constants {
        static let maximumParticleBudget = 350
        static let snowLifetime: Float = 18
        static let sparkleLifetime: Float = 4
    }

    private struct RenderState: Equatable {
        var style: EffectStyle
        var density: Double
        var speed: Double
    }

    private static var textureCache: [String: CGImage] = [:]

    private var renderState: RenderState?
    private var configuration = EffectConfiguration().normalized
    private var emitterLayer: CAEmitterLayer?
    private var occlusionObserver: NSObjectProtocol?

    public private(set) var isPaused = false
    public private(set) var particleBudget = 0

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    deinit {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
    }

    public func apply(_ configuration: EffectConfiguration) {
        let normalized = configuration.normalized
        let nextState = RenderState(
            style: normalized.style,
            density: normalized.density,
            speed: normalized.speed
        )

        self.configuration = normalized

        if renderState != nextState {
            renderState = nextState
            rebuildEmitter()
        } else {
            setEmitterOpacity()
        }
    }

    public func setPaused(_ paused: Bool) {
        guard paused != isPaused else {
            return
        }

        isPaused = paused
        guard let emitterLayer else {
            return
        }

        withoutImplicitAnimations {
            if paused {
                pause(emitterLayer)
            } else {
                resume(emitterLayer)
            }
        }
    }

    public override func layout() {
        super.layout()
        guard let emitterLayer else {
            return
        }

        withoutImplicitAnimations {
            emitterLayer.frame = bounds
            emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
            emitterLayer.emitterSize = bounds.size
        }
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard renderState != nil else {
            return
        }
        rebuildEmitter()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }

        guard let window else {
            return
        }

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, let window else {
                    return
                }
                self.setPaused(!window.occlusionState.contains(.visible))
            }
        }
        setPaused(!window.occlusionState.contains(.visible))
    }

    private func configureLayer() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        layer?.opacity = 1
    }

    private func rebuildEmitter() {
        let newEmitter = CAEmitterLayer()
        let budget = Int((Double(Constants.maximumParticleBudget) * configuration.density).rounded())
        particleBudget = min(max(budget, 0), Constants.maximumParticleBudget)

        newEmitter.frame = bounds
        newEmitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        newEmitter.emitterSize = bounds.size
        newEmitter.emitterShape = .rectangle
        newEmitter.emitterMode = .volume
        newEmitter.renderMode = configuration.style == .snow ? .unordered : .additive
        newEmitter.opacity = Float(configuration.opacity)

        let speed = Float(0.25 + configuration.speed * 1.5)
        switch configuration.style {
        case .snow:
            newEmitter.emitterCells = [makeSnowCell(budget: particleBudget, speed: speed)]
        case .sparkle:
            newEmitter.emitterCells = [makeSparkleCell(budget: particleBudget, speed: speed)]
        case .festive:
            let snowBudget = Int(Double(particleBudget) * 0.62)
            let sparkleBudget = particleBudget - snowBudget
            newEmitter.emitterCells = [
                makeSnowCell(budget: snowBudget, speed: speed),
                makeSparkleCell(budget: sparkleBudget, speed: speed)
            ]
        }

        withoutImplicitAnimations {
            emitterLayer?.removeFromSuperlayer()
            layer?.addSublayer(newEmitter)
            emitterLayer = newEmitter
            if isPaused {
                pause(newEmitter)
            }
        }
    }

    private func makeSnowCell(budget: Int, speed: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = texture(for: .snow)
        cell.birthRate = birthRate(budget: budget, lifetime: Constants.snowLifetime)
        cell.lifetime = Constants.snowLifetime
        cell.velocity = CGFloat(5 * speed)
        cell.velocityRange = CGFloat(8 * speed)
        cell.yAcceleration = CGFloat(2 * speed)
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 3
        cell.scale = 0.55
        cell.scaleRange = 0.45
        cell.alphaRange = 0.18
        return cell
    }

    private func makeSparkleCell(budget: Int, speed: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = texture(for: .sparkle)
        cell.birthRate = birthRate(budget: budget, lifetime: Constants.sparkleLifetime)
        cell.lifetime = Constants.sparkleLifetime
        cell.velocity = 0
        cell.scale = 0.65
        cell.scaleRange = 0.4
        cell.alphaSpeed = -0.25 * speed
        cell.spinRange = .pi
        return cell
    }

    private func birthRate(budget: Int, lifetime: Float) -> Float {
        guard budget > 0 else {
            return 0
        }
        return Float(budget) / lifetime
    }

    private func setEmitterOpacity() {
        withoutImplicitAnimations {
            emitterLayer?.opacity = Float(configuration.opacity)
        }
    }

    private func pause(_ layer: CALayer) {
        layer.timeOffset = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
    }

    private func resume(_ layer: CALayer) {
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
    }

    private func texture(for style: EffectStyle) -> CGImage? {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let key = "\(style.rawValue)-\(scale)"
        if let cached = Self.textureCache[key] {
            return cached
        }

        let image = makeTexture(style: style, scale: scale)
        if let image {
            Self.textureCache[key] = image
        }
        return image
    }

    private func makeTexture(style: EffectStyle, scale: CGFloat) -> CGImage? {
        let pointSize: CGFloat = style == .sparkle ? 16 : 10
        let pixelSize = max(Int((pointSize * scale).rounded()), 1)
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setAllowsAntialiasing(true)
        context.setFillColor(NSColor.white.cgColor)
        let center = CGFloat(pixelSize) / 2
        if style == .snow {
            context.fillEllipse(in: CGRect(x: center - center * 0.55, y: center - center * 0.55, width: center * 1.1, height: center * 1.1))
        } else {
            context.setLineCap(.round)
            context.setLineWidth(max(scale, 1))
            context.move(to: CGPoint(x: center, y: scale))
            context.addLine(to: CGPoint(x: center, y: CGFloat(pixelSize) - scale))
            context.move(to: CGPoint(x: scale, y: center))
            context.addLine(to: CGPoint(x: CGFloat(pixelSize) - scale, y: center))
            context.strokePath()
            context.fillEllipse(in: CGRect(x: center - scale, y: center - scale, width: scale * 2, height: scale * 2))
        }
        return context.makeImage()
    }

    private func withoutImplicitAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}
