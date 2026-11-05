import MapKit
import SpriteKit
import TornadoCore

@MainActor
final class TornadoScene: SKScene {
    weak var session: GameSession?
    private(set) var simulation: Simulation
    private let ground = SKNode()
    private var weatherZoneNodes: [SKShapeNode] = []
    private var overlapNodes: [SKShapeNode] = []
    private let objectsLayer = SKNode()
    private let effects = SKNode()
    private let tornado = SKNode()
    private var vortexAnimation = VortexAnimation()
    private var vortexSprite: SKSpriteNode?
    private var vortexFrame = 0
    // Shared atlas/subtextures survive scene changes; no texture allocation in update.
    private static let vortexFrames: [SKTexture] = {
        let atlas = SKTexture(imageNamed: "TornadoVortexAtlas")
        atlas.filteringMode = .linear
        return (0..<VortexAnimation.frameCount).map { index in
            let column = index % VortexAnimation.columns
            let row = index / VortexAnimation.columns
            // PNG rows start at the top; SpriteKit texture coordinates start below.
            let region = CGRect(
                x: CGFloat(column) / CGFloat(VortexAnimation.columns),
                y: CGFloat(VortexAnimation.rows - row - 1) / CGFloat(VortexAnimation.rows),
                width: 1 / CGFloat(VortexAnimation.columns),
                height: 1 / CGFloat(VortexAnimation.rows))
            let texture = SKTexture(rect: region, in: atlas)
            texture.filteringMode = .linear
            return texture
        }
    }()
    private let cameraNode = SKCameraNode()
    private var objectNodes: [Int: SKNode] = [:]
    private var direction = Point(0, 0)
    private var previousTime: TimeInterval?
    private var hudTime: Double = 0
    private var snapshotter: MKMapSnapshotter?
    private var built = false
    private var liftingIDs: Set<Int> = []

    init(level: Level, progress: TornadoCore.Progress) {
        simulation = Simulation(level: level, progress: progress)
        super.init(size: CGSize(width: 896, height: 414))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.06, green: 0.10, blue: 0.13, alpha: 1)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("Scene is created in code") }
    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 60
        guard !built else { return }
        built = true
        addChild(ground)
        addChild(objectsLayer)
        addChild(effects)
        objectsLayer.zPosition = 3
        effects.zPosition = 6
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
        guard let previousTime else {
            self.previousTime = currentTime
            return
        }
        self.previousTime = currentTime
        let delta = min(max(currentTime - previousTime, 0), 0.05)
        guard !isPaused else { return }
        let result = simulation.step(delta: delta, direction: direction)
        updateWeatherZoneNodes()
        updateOverlapNodes()
        for id in result.destroyed { destroy(id) }
        updateLiftingObjects()
        tornado.position = CGPoint(x: simulation.position.x, y: simulation.position.y)
        // The animated spiral widens naturally as the tornado strengthens.
        let baseScale = simulation.radius / 26
        tornado.setScale(baseScale)
        updateVortex(delta: delta)
        updateCamera()
        hudTime += delta
        let publish = hudTime >= 0.1
        if publish { hudTime = 0 }
        session?.receive(simulation, result: result, publishHUD: publish)
    }
    private func makeGround() {
        let width = Level.worldSize.x
        let height = Level.worldSize.y
        // Honest offline surface: no invented street geometry.
        let grid = CGMutablePath()
        for x in stride(from: 0.0, through: width, by: 100) {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0.0, through: height, by: 100) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: width, y: y))
        }
        let gridNode = SKShapeNode(path: grid)
        gridNode.strokeColor = .white.withAlphaComponent(0.06)
        gridNode.lineWidth = 1
        ground.addChild(gridNode)
        for zone in simulation.weatherZones {
            let ring = SKShapeNode(circleOfRadius: zone.radius)
            ring.position = CGPoint(x: zone.center.x, y: zone.center.y)
            let color: UIColor = zone.favorable ? .systemMint : .systemBlue
            ring.fillColor = color.withAlphaComponent(0.12)
            ring.strokeColor = color.withAlphaComponent(0.4)
            ring.lineWidth = 3
            ring.zPosition = 1
            ground.addChild(ring)
            weatherZoneNodes.append(ring)
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = zone.favorable ? "WARM + MOIST" : "COOL + DRY"
            label.fontSize = 17
            label.fontColor = color.withAlphaComponent(0.8)
            label.position = CGPoint(x: 0, y: zone.radius - 45)
            ring.addChild(label)
        }
        // One reusable ellipse per possible pair of bubbles (four bubbles make six pairs).
        // Each is scaled and rotated to cover the lens where two bubbles overlap; no per-frame allocation.
        let pairCount = simulation.weatherZones.count * (simulation.weatherZones.count - 1) / 2
        for _ in 0..<pairCount {
            let lens = SKShapeNode(circleOfRadius: 1)
            lens.lineWidth = 0
            lens.zPosition = 1.5
            lens.isHidden = true
            ground.addChild(lens)
            overlapNodes.append(lens)
        }
        updateOverlapNodes()
        let border = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: height))
        border.strokeColor = .white.withAlphaComponent(0.4)
        border.lineWidth = 5
        border.zPosition = 2
        ground.addChild(border)
    }
    private func updateWeatherZoneNodes() {
        // Move only the ring nodes; labels travel with each ring as children.
        // No new SpriteKit objects or textures are allocated per update.
        for (node, zone) in zip(weatherZoneNodes, simulation.weatherZones) {
            node.position = CGPoint(x: zone.center.x, y: zone.center.y)
        }
    }
    private func updateOverlapNodes() {
        let overlaps = simulation.weatherOverlaps
        for (index, node) in overlapNodes.enumerated() {
            guard index < overlaps.count else {
                node.isHidden = true
                continue
            }
            let overlap = overlaps[index]
            let color: UIColor
            switch overlap.outcome {
            case .superWarm: color = .systemOrange
            case .superDry: color = .systemIndigo
            default: color = .systemYellow
            }
            node.isHidden = false
            node.fillColor = color.withAlphaComponent(0.38)
            node.position = CGPoint(x: overlap.center.x, y: overlap.center.y)
            node.zRotation = CGFloat(overlap.angle)
            node.xScale = CGFloat(max(overlap.halfLength, 1))
            node.yScale = CGFloat(max(overlap.halfWidth, 1))
        }
    }
    private func makeObjects() {
        for object in simulation.objects {
            let node = SKNode()
            node.name = "object-\(object.id)"
            node.position = CGPoint(x: object.position.x, y: object.position.y)
            switch object.kind {
            case .tree:
                let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 17))
                shadow.fillColor = .black.withAlphaComponent(0.25)
                shadow.strokeColor = .clear
                shadow.position = CGPoint(x: 4, y: -5)
                node.addChild(shadow)
                let tree = SKSpriteNode(imageNamed: "Tree")
                tree.size = CGSize(width: 28, height: 28)
                node.addChild(tree)
            case .car:
                let shadow = SKShapeNode(ellipseOf: CGSize(width: 13, height: 23))
                shadow.fillColor = .black.withAlphaComponent(0.28)
                shadow.strokeColor = .clear
                shadow.position = CGPoint(x: 2, y: -3)
                node.addChild(shadow)
                let carAssets = ["CarGray", "CarBlue", "CarRed", "CarWhite"]
                let car = SKSpriteNode(imageNamed: carAssets[object.id % carAssets.count])
                // The art faces right. Rotate it so vehicles face north on the map.
                car.size = CGSize(width: 24, height: 14)
                car.zRotation = .pi / 2
                node.addChild(car)
            case .house, .block:
                let big = object.kind == .block
                let body = SKShapeNode(rectOf: CGSize(width: big ? 37 : 26, height: big ? 44 : 29), cornerRadius: 3)
                body.fillColor =
                    big
                    ? UIColor(red: 0.49, green: 0.53, blue: 0.62, alpha: 1)
                    : UIColor(red: 0.67, green: 0.50, blue: 0.42, alpha: 1)
                body.strokeColor = .white.withAlphaComponent(0.4)
                body.lineWidth = 2
                node.addChild(body)
                let roof = SKShapeNode(rectOf: CGSize(width: big ? 24 : 18, height: 3))
                roof.fillColor = .white.withAlphaComponent(0.25)
                roof.strokeColor = .clear
                node.addChild(roof)
            }
            node.zRotation = CGFloat(object.id % 3) * 0.16
            objectNodes[object.id] = node
            objectsLayer.addChild(node)
        }
    }
    private func makeTornado() {
        tornado.name = "tornado"
        tornado.zPosition = 8
        addChild(tornado)
        let vortex = SKSpriteNode(texture: Self.vortexFrames[0], size: CGSize(width: 58, height: 58))
        vortex.name = "vortexSprite"
        tornado.addChild(vortex)
        vortexSprite = vortex
        tornado.setScale(simulation.radius / 26)
        tornado.position = CGPoint(x: simulation.position.x, y: simulation.position.y)
    }
    private func updateVortex(delta: TimeInterval) {
        vortexAnimation.advance(delta: delta, energy: simulation.energy)
        let frame = vortexAnimation.frameIndex
        if frame != vortexFrame {
            vortexSprite?.texture = Self.vortexFrames[frame]
            vortexFrame = frame
        }
        vortexSprite?.zRotation = CGFloat(vortexAnimation.residualAngle)
    }
    private func updateLiftingObjects() {
        var active: Set<Int> = []
        for object in simulation.objects where simulation.canLift(object) && object.damage > 0 {
            guard let node = objectNodes[object.id] else { continue }
            active.insert(object.id)
            let amount = min(1, object.damage)
            let light = object.kind == .tree || object.kind == .car
            let pull = amount * (light ? 0.3 : 0.08)
            node.position = CGPoint(
                x: object.position.x + (simulation.position.x - object.position.x) * pull,
                y: object.position.y + (simulation.position.y - object.position.y) * pull + amount * (light ? 14 : 3))
            node.zRotation = CGFloat(object.id % 3) * 0.16
                + CGFloat(sin(simulation.elapsed * 35 + Double(object.id)) * amount * (light ? 0.4 : 0.08))
            node.setScale(1 + amount * (light ? 0.15 : 0.04))
            node.zPosition = light ? 2 : 1
        }
        for id in liftingIDs.subtracting(active) {
            guard let node = objectNodes[id] else { continue }
            let object = simulation.objects[id]
            node.position = CGPoint(x: object.position.x, y: object.position.y)
            node.zRotation = CGFloat(id % 3) * 0.16
            node.setScale(1)
            node.zPosition = 0
        }
        liftingIDs = active
    }
    private func destroy(_ id: Int) {
        guard let node = objectNodes.removeValue(forKey: id) else { return }
        let origin = node.position
        let kind = simulation.objects[id].kind
        node.removeFromParent()
        let rubble = SKShapeNode(ellipseOf: CGSize(width: 19, height: 13))
        rubble.position = origin
        rubble.fillColor = .black.withAlphaComponent(0.24)
        rubble.strokeColor = .clear
        objectsLayer.addChild(rubble)
        // Bounded transient debris, with no per-fragment physics simulation.
        for index in 0..<7 {
            let fragment = SKShapeNode(rectOf: CGSize(width: 4, height: 7))
            fragment.fillColor = kind == .tree ? .systemGreen : .lightGray
            fragment.strokeColor = .clear
            fragment.position = origin
            effects.addChild(fragment)
            let angle = Double(index) / 7 * .pi * 2 + Double(id)
            let target = CGPoint(
                x: simulation.position.x + cos(angle) * 45,
                y: simulation.position.y + sin(angle) * 45)
            fragment.run(
                .sequence([
                    .group([
                        .move(to: target, duration: 0.65),
                        .rotate(byAngle: .pi * 3, duration: 0.65),
                        .fadeOut(withDuration: 0.75),
                    ]), .removeFromParent(),
                ]))
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(kind.coins) TC"
        label.fontSize = 17
        label.fontColor = .systemYellow
        label.position = origin
        label.zPosition = 10
        effects.addChild(label)
        label.run(
            .sequence([
                .group([.moveBy(x: 0, y: 42, duration: 0.85), .fadeOut(withDuration: 0.85)]), .removeFromParent(),
            ]))
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
        let topLeft = MKMapPoint(
            CLLocationCoordinate2D(
                latitude: level.center.latitude + level.latitudeSpan / 2,
                longitude: level.center.longitude - level.longitudeSpan / 2))
        let bottomRight = MKMapPoint(
            CLLocationCoordinate2D(
                latitude: level.center.latitude - level.latitudeSpan / 2,
                longitude: level.center.longitude + level.longitudeSpan / 2))
        let rect = MKMapRect(
            x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
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
            map.anchorPoint = .zero
            map.position = .zero
            map.size = CGSize(width: Level.worldSize.x, height: Level.worldSize.y)
            map.color = UIColor(red: 0.12, green: 0.18, blue: 0.22, alpha: 1)
            map.colorBlendFactor = 0.20
            map.zPosition = -1
            self.ground.addChild(map)
            self.session?.mapStatus = "Apple Maps"
            self.snapshotter = nil
        }
    }
    func stop() {
        snapshotter?.cancel()
        snapshotter = nil
        isPaused = true
        direction = Point(0, 0)
    }
}

