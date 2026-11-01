import SpriteKit
import MapKit
import TornadoCore

@MainActor
final class TornadoScene: SKScene {
    weak var session: GameSession?
    private(set) var simulation: Simulation
    private let ground = SKNode()
    private let objectsLayer = SKNode()
    private let effects = SKNode()
    private let tornado = SKNode()
    private let cameraNode = SKCameraNode()
    private var objectNodes: [Int: SKNode] = [:]
    private var direction = Point(0, 0)
    private var previousTime: TimeInterval?
    private var hudTime: Double = 0
    private var snapshotter: MKMapSnapshotter?
    private var built = false
    private var lastEF = -1
    private let core = SKShapeNode(circleOfRadius: 10)
    private let halo = SKShapeNode(circleOfRadius: 26)

    init(level: Level, progress: Progress) {
        simulation = Simulation(level: level, progress: progress)
        super.init(size: CGSize(width: 414, height: 896))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.06, green: 0.10, blue: 0.13, alpha: 1)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("Scene is created in code") }
    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        addChild(ground); addChild(objectsLayer); addChild(effects)
        objectsLayer.zPosition = 3; effects.zPosition = 6
        makeGround()
        makeObjects()
        makeTornado()
        camera = cameraNode
        cameraNode.setScale(1.42)
        addChild(cameraNode)
        updateCamera()
        loadMap()
    }
    func setDirection(_ value: Point) { direction = value }
    func resetClock() { previousTime = nil }
    override func update(_ currentTime: TimeInterval) {
        guard let previousTime else { self.previousTime = currentTime; return }
        self.previousTime = currentTime
        let delta = min(max(currentTime - previousTime, 0), 0.05)
        guard !isPaused else { return }
        let result = simulation.step(delta: delta, direction: direction)
        for id in result.destroyed { destroy(id) }
        tornado.position = CGPoint(x: simulation.position.x, y: simulation.position.y)
        // A thin rope at EF0 broadens into a wider, rounder circulation at EF5.
        let baseScale = simulation.radius / 26
        tornado.xScale = baseScale * (0.72 + Double(simulation.ef) * 0.056)
        tornado.yScale = baseScale * (1.08 - Double(simulation.ef) * 0.016)
        if lastEF != simulation.ef {
            lastEF = simulation.ef
            let colors: [UIColor] = [.systemMint, .systemTeal, .systemCyan, .systemYellow, .systemOrange, .systemRed]
            core.fillColor = colors[lastEF].withAlphaComponent(0.9)
            halo.strokeColor = colors[lastEF].withAlphaComponent(0.55)
        }
        updateCamera()
        hudTime += delta
        let publish = hudTime >= 0.1
        if publish { hudTime = 0 }
        session?.receive(simulation, result: result, publishHUD: publish)
    }
    private func makeGround() {
        let width = Level.worldSize.x, height = Level.worldSize.y
        // Honest offline surface: no invented street geometry.
        let grid = CGMutablePath()
        for x in stride(from: 0.0, through: width, by: 100) {
            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0.0, through: height, by: 100) {
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: width, y: y))
        }
        let gridNode = SKShapeNode(path: grid)
        gridNode.strokeColor = .white.withAlphaComponent(0.06); gridNode.lineWidth = 1
        ground.addChild(gridNode)
        for zone in simulation.level.zones {
            let ring = SKShapeNode(circleOfRadius: zone.radius)
            ring.position = CGPoint(x: zone.center.x, y: zone.center.y)
            let color: UIColor = zone.favorable ? .systemMint : .systemBlue
            ring.fillColor = color.withAlphaComponent(0.12)
            ring.strokeColor = color.withAlphaComponent(0.4)
            ring.lineWidth = 3; ring.zPosition = 1
            ground.addChild(ring)
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = zone.favorable ? "WARM + MOIST" : "COOL + DRY"
            label.fontSize = 17; label.fontColor = color.withAlphaComponent(0.8)
            label.position = CGPoint(x: 0, y: zone.radius - 45)
            ring.addChild(label)
        }
        let border = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: height))
        border.strokeColor = .white.withAlphaComponent(0.4); border.lineWidth = 5
        border.zPosition = 2; ground.addChild(border)
    }
    private func makeObjects() {
        for object in simulation.objects {
            let node = SKNode()
            node.position = CGPoint(x: object.position.x, y: object.position.y)
            switch object.kind {
            case .tree:
                let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 18))
                shadow.fillColor = .black.withAlphaComponent(0.25); shadow.strokeColor = .clear
                shadow.position = CGPoint(x: 4, y: -5); node.addChild(shadow)
                let tree = SKShapeNode(circleOfRadius: 11)
                tree.fillColor = UIColor(red: 0.26, green: 0.52, blue: 0.39, alpha: 1)
                tree.strokeColor = UIColor.systemMint.withAlphaComponent(0.35)
                node.addChild(tree)
                let leaf = SKShapeNode(circleOfRadius: 5)
                leaf.position = CGPoint(x: -3, y: 3); leaf.fillColor = .white.withAlphaComponent(0.12)
                leaf.strokeColor = .clear; node.addChild(leaf)
            case .car:
                let car = SKShapeNode(rectOf: CGSize(width: 12, height: 23), cornerRadius: 3)
                car.fillColor = object.id % 2 == 0 ? .systemYellow : .systemCyan
                car.strokeColor = .black.withAlphaComponent(0.5); car.lineWidth = 2
                node.addChild(car)
                let glass = SKShapeNode(rectOf: CGSize(width: 8, height: 7), cornerRadius: 1)
                glass.fillColor = UIColor(white: 0.12, alpha: 1); glass.strokeColor = .clear
                glass.position.y = 2; node.addChild(glass)
            case .house, .block:
                let big = object.kind == .block
                let body = SKShapeNode(rectOf: CGSize(width: big ? 37 : 26, height: big ? 44 : 29), cornerRadius: 3)
                body.fillColor = big ? UIColor(red: 0.49, green: 0.53, blue: 0.62, alpha: 1) : UIColor(red: 0.67, green: 0.50, blue: 0.42, alpha: 1)
                body.strokeColor = .white.withAlphaComponent(0.4); body.lineWidth = 2
                node.addChild(body)
                let roof = SKShapeNode(rectOf: CGSize(width: big ? 24 : 18, height: 3))
                roof.fillColor = .white.withAlphaComponent(0.25); roof.strokeColor = .clear
                node.addChild(roof)
            }
            node.zRotation = CGFloat(object.id % 3) * 0.16
            objectNodes[object.id] = node
            objectsLayer.addChild(node)
        }
    }
    private func makeTornado() {
        tornado.zPosition = 8; addChild(tornado)
        halo.fillColor = .black.withAlphaComponent(0.22)
        halo.lineWidth = 1; tornado.addChild(halo)
        for index in 0..<6 {
            let radius = CGFloat(9 + index * 3)
            let path = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: 0,
                                    endAngle: .pi * 1.55, clockwise: true)
            let ring = SKShapeNode(path: path.cgPath)
            ring.strokeColor = UIColor(white: 0.92, alpha: 0.32 + Double(index) * 0.07)
            ring.lineWidth = CGFloat(2 + index / 2)
            ring.zRotation = CGFloat(index) * 1.4
            ring.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.65 + Double(index) * 0.16)))
            tornado.addChild(ring)
        }
        core.strokeColor = .white.withAlphaComponent(0.55); core.lineWidth = 1
        tornado.addChild(core)
        let eye = SKShapeNode(circleOfRadius: 4)
        eye.fillColor = .black.withAlphaComponent(0.65); eye.strokeColor = .clear
        tornado.addChild(eye)
        tornado.position = CGPoint(x: simulation.position.x, y: simulation.position.y)
    }
    private func destroy(_ id: Int) {
        guard let node = objectNodes.removeValue(forKey: id) else { return }
        let origin = node.position
        let kind = simulation.objects[id].kind
        node.removeFromParent()
        let rubble = SKShapeNode(ellipseOf: CGSize(width: 19, height: 13))
        rubble.position = origin; rubble.fillColor = .black.withAlphaComponent(0.24)
        rubble.strokeColor = .clear; objectsLayer.addChild(rubble)
        // Bounded transient debris, with no per-fragment physics simulation.
        for index in 0..<7 {
            let fragment = SKShapeNode(rectOf: CGSize(width: 4, height: 7))
            fragment.fillColor = kind == .tree ? .systemGreen : .lightGray
            fragment.strokeColor = .clear; fragment.position = origin
            effects.addChild(fragment)
            let angle = Double(index) / 7 * .pi * 2 + Double(id)
            let target = CGPoint(x: simulation.position.x + cos(angle) * 45,
                                 y: simulation.position.y + sin(angle) * 45)
            fragment.run(.sequence([.group([.move(to: target, duration: 0.65),
                                            .rotate(byAngle: .pi * 3, duration: 0.65),
                                            .fadeOut(withDuration: 0.75)]), .removeFromParent()]))
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(kind.coins) TC"; label.fontSize = 17; label.fontColor = .systemYellow
        label.position = origin; label.zPosition = 10; effects.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 42, duration: 0.85), .fadeOut(withDuration: 0.85)]), .removeFromParent()]))
        if kind == .house || kind == .block {
            cameraNode.run(.sequence([.moveBy(x: 2, y: 0, duration: 0.04), .moveBy(x: -2, y: 0, duration: 0.04)]))
        }
    }
    private func updateCamera() {
        // Keep the tornado visible between HUD and controls, including at world edges.
        // The bounded playfield may end within the viewport; controls never cover the player.
        cameraNode.position = CGPoint(x: simulation.position.x, y: simulation.position.y + 45)
    }
    private func loadMap() {
        let level = simulation.level
        let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: level.center.latitude + level.latitudeSpan / 2,
                                                       longitude: level.center.longitude - level.longitudeSpan / 2))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: level.center.latitude - level.latitudeSpan / 2,
                                                           longitude: level.center.longitude + level.longitudeSpan / 2))
        let rect = MKMapRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = CGSize(width: 1024, height: 1024 * rect.height / rect.width)
        options.scale = 1
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        snapshotter = MKMapSnapshotter(options: options)
        snapshotter?.start(with: .main) { [weak self] snapshot, _ in
            guard let self else { return }
            guard let snapshot else {
                self.session?.mapStatus = "Map unavailable · reference grid"
                return
            }
            let map = SKSpriteNode(texture: SKTexture(image: snapshot.image))
            map.anchorPoint = .zero; map.position = .zero
            map.size = CGSize(width: Level.worldSize.x, height: Level.worldSize.y)
            map.color = UIColor(red: 0.12, green: 0.18, blue: 0.22, alpha: 1)
            map.colorBlendFactor = 0.20
            map.zPosition = -1; self.ground.addChild(map)
            self.session?.mapStatus = "Apple Maps"
            self.snapshotter = nil
        }
    }
    func stop() {
        snapshotter?.cancel(); snapshotter = nil
        isPaused = true; direction = Point(0, 0)
    }
}
