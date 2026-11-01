import Foundation

public enum Weather: String, Sendable {
    case warm = "Warm & moist"
    case mixed = "Mixed air"
    case dry = "Cool & dry"
    public var hint: String {
        switch self {
        case .warm: return "Strengthening"
        case .mixed: return "Slow growth"
        case .dry: return "Losing energy"
        }
    }
}

public struct StepResult {
    public init() {}
    public var destroyed: [Int] = []
    public var newQuests: [QuestKind] = []
    public var finished = false
}

/// Deterministic, framework-independent gameplay. One instance is one run.
public struct Simulation {
    public let level: Level
    public let ranks: [Upgrade: Int]
    public private(set) var position: Point
    public private(set) var energy: Double = 8
    public private(set) var elapsed: Double = 0
    public private(set) var peakEF = 0
    public private(set) var destroyedCount = 0
    public private(set) var objects: [WorldObject]
    public private(set) var achieved: Set<QuestKind> = []
    public private(set) var finished = false
    public private(set) var dissipated = false
    private var emptyTime: Double = 0
    public static let thresholds: [Double] = [0, 18, 36, 55, 76, 93]
    public var ef: Int { Self.thresholds.lastIndex(where: { energy >= $0 }) ?? 0 }
    /// Gameplay estimate, not a measurement or real-time weather report.
    public var wind: Int {
        // NWS EF wind bands. Energy drives the game, not a real storm measurement.
        let lower = [65, 86, 111, 136, 166, 201]
        let upper = [85, 110, 135, 165, 200, 220]
        let category = ef
        let ceiling = category == 5 ? 100 : Self.thresholds[category + 1]
        let fraction = (energy - Self.thresholds[category]) / (ceiling - Self.thresholds[category])
        return min(upper[category], lower[category] + Int(fraction * Double(upper[category] - lower[category] + 1)))
    }
    public var dissipationRemaining: Int { max(0, Int(ceil(8 - emptyTime))) }
    public var radius: Double { 20 + energy * 0.53 }
    public var liftingPower: Double { energy * (1 + Double(ranks[.suction, default: 0]) * 0.10) }
    public var speed: Double { 135 * (1 + Double(ranks[.speed, default: 0]) * 0.12) }
    public var weather: Weather {
        for zone in level.zones where position.distance(to: zone.center) < zone.radius {
            return zone.favorable ? .warm : .dry
        }
        return .mixed
    }
    public init(level: Level, progress: Progress = Progress()) {
        self.level = level
        self.position = level.start
        self.ranks = Dictionary(uniqueKeysWithValues: Upgrade.allCases.map { ($0, progress.rank($0)) })
        self.objects = Self.makeObjects(level)
    }
    public func value(for quest: Quest) -> Int {
        switch quest.kind {
        case .strength: return peakEF
        case .destruction: return destroyedCount
        case .survival: return Int(elapsed)
        }
    }
    public func canLift(_ object: WorldObject) -> Bool {
        !object.destroyed && position.distance(to: object.position) <= radius + 9
            && liftingPower >= object.kind.resistance
    }
    /// Direction is a normalized virtual joystick vector. Simulation time freezes while paused.
    public mutating func step(delta: Double, direction: Point) -> StepResult {
        var result = StepResult()
        guard !finished, !dissipated, delta.isFinite, delta > 0 else { return result }
        let dt = min(delta, 0.1)
        elapsed += dt
        let magnitude = hypot(direction.x, direction.y)
        if magnitude.isFinite, magnitude > 0 {
            let divisor = max(1, magnitude)
            position.x += direction.x / divisor * speed * dt
            position.y += direction.y / divisor * speed * dt
        }
        position.x = min(max(24, position.x), Level.worldSize.x - 24)
        position.y = min(max(24, position.y), Level.worldSize.y - 24)
        let rate: Double
        switch weather {
        case .warm: rate = level.growth
        case .mixed: rate = level.growth * 0.22
        case .dry: rate = -level.loss * (1 - 0.14 * Double(ranks[.stability, default: 0]))
        }
        energy = min(100, max(0, energy + rate * dt))
        peakEF = max(peakEF, ef)
        emptyTime = energy <= 0 ? emptyTime + dt : 0
        if emptyTime >= 8 {
            dissipated = true
            return result
        }
        for index in objects.indices where !objects[index].destroyed {
            let object = objects[index]
            guard canLift(object) else { continue }
            // Buildings take a little longer to break apart than trees and cars.
            let duration: Double = object.kind == .house || object.kind == .block ? 0.85 : 0.3
            objects[index].damage += dt / duration
            if objects[index].damage >= 1 {
                objects[index].destroyed = true
                destroyedCount += 1
                result.destroyed.append(object.id)
            }
        }
        for quest in level.quests where !achieved.contains(quest.kind) && value(for: quest) >= quest.target {
            achieved.insert(quest.kind)
            result.newQuests.append(quest.kind)
        }
        if achieved.count == level.quests.count {
            finished = true
            result.finished = true
        }
        return result
    }
    private static func makeObjects(_ level: Level) -> [WorldObject] {
        var objects: [WorldObject] = []
        // Stable small clusters anchored to surveyed map coordinates. Decorative offsets are in world units.
        for (cluster, coordinate) in level.anchors.enumerated() {
            let anchor = level.point(for: coordinate)
            for index in 0..<15 {
                let angle = Double(index) * 2.39996
                let distance = 15 + Double(index / 3) * 24
                let point = Point(
                    min(max(35, anchor.x + cos(angle) * distance), Level.worldSize.x - 35),
                    min(max(35, anchor.y + sin(angle) * distance), Level.worldSize.y - 35))
                let kind: ObjectKind
                switch index % 5 {
                case 1 where level.id == "chicago": kind = .car
                case 2 where level.id == "chicago": kind = .house
                case 3 where level.id == "chicago": kind = .block
                case 0, 1: kind = .tree
                case 2: kind = .car
                case 3: kind = .house
                default: kind = level.id == "moore" ? .house : .block
                }
                objects.append(WorldObject(id: cluster * 15 + index, kind: kind, position: point))
            }
        }
        return objects
    }
}

