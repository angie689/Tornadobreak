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
    private var stationaryTime: Double = 0
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
    /// Weather drifts during the run; Moore remains static as the introductory level.
    /// All offsets start at zero, so a fresh run always begins in favorable air.
    public var weatherZones: [WeatherZone] {
        let drift = level.tuning.drift
        let period = level.tuning.driftPeriod
        guard drift > 0, period > 0 else { return level.zones }
        let phase = elapsed * 2 * Double.pi / period
        return level.zones.enumerated().map { index, zone in
            let offset = Double(index)
            let strength = index < 2 ? drift : drift * 0.48
            let x = zone.center.x + (sin(phase + offset * 0.7) - sin(offset * 0.7)) * strength
            let y = zone.center.y + (cos(phase + offset * 0.8) - cos(offset * 0.8)) * strength * 0.75
            return WeatherZone(
                center: Point(
                    min(max(40, x), Level.worldSize.x - 40),
                    min(max(40, y), Level.worldSize.y - 40)),
                radius: zone.radius, favorable: zone.favorable)
        }
    }
    public var weather: Weather {
        for zone in weatherZones where position.distance(to: zone.center) < zone.radius {
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
    /// Lifting power an object needs in this city; later cities use sturdier buildings.
    public func requiredPower(for object: WorldObject) -> Double {
        object.kind.resistance * level.tuning.resistance
    }
    public func canLift(_ object: WorldObject) -> Bool {
        !object.destroyed && position.distance(to: object.position) <= radius + 9
            && liftingPower >= requiredPower(for: object)
    }
    /// Direction is a normalized virtual joystick vector. Simulation time freezes while paused.
    public mutating func step(delta: Double, direction: Point) -> StepResult {
        var result = StepResult()
        guard !finished, !dissipated, delta.isFinite, delta > 0 else { return result }
        let dt = min(delta, 0.1)
        elapsed += dt
        let magnitude = hypot(direction.x, direction.y)
        if magnitude.isFinite, magnitude > 0.08 {
            stationaryTime = 0
            let divisor = max(1, magnitude)
            position.x += direction.x / divisor * speed * dt
            position.y += direction.y / divisor * speed * dt
        } else {
            stationaryTime += dt
        }
        position.x = min(max(24, position.x), Level.worldSize.x - 24)
        position.y = min(max(24, position.y), Level.worldSize.y - 24)
        let rate: Double
        switch weather {
        case .warm:
            // In Dallas and Chicago, camping in one spot stops being an easy EF5 strategy.
            let delay = level.tuning.campDelay
            rate = level.growth * (delay > 0 && stationaryTime > delay ? 0.12 : 1)
        case .mixed:
            rate = level.growth * level.tuning.mixedGrowth - level.tuning.mixedLoss
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
                // Large debris loads disrupt the circulation; trees and cars stay cheap.
                if object.kind == .house || object.kind == .block {
                    let load = object.kind == .block ? 1.2 : 0.45
                    energy = max(0, energy - load * level.tuning.debris)
                }
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
        // Stable small clusters anchored to map reference coordinates. Decorative offsets are in world units.
        for (cluster, coordinate) in level.anchors.enumerated() {
            let anchor = level.point(for: coordinate)
            for index in 0..<15 {
                let angle = Double(index) * 2.39996
                let distance = 15 + Double(index / 3) * 24
                let point = Point(
                    min(max(35, anchor.x + cos(angle) * distance), Level.worldSize.x - 35),
                    min(max(35, anchor.y + sin(angle) * distance), Level.worldSize.y - 35))
                let kind = level.tuning.mix.kind(slot: index)
                objects.append(WorldObject(id: cluster * 15 + index, kind: kind, position: point))
            }
        }
        return objects
    }
}

