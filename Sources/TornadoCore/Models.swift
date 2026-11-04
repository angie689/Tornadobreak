import Foundation

public struct Point: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
    public func distance(to other: Point) -> Double { hypot(x - other.x, y - other.y) }
}

public struct Coordinate: Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum ObjectKind: String, CaseIterable, Sendable {
    case tree, car, house, block
    public var resistance: Double {
        switch self {
        case .tree: return 3
        case .car: return 27
        case .house: return 52
        case .block: return 76
        }
    }
    public var coins: Int {
        switch self {
        case .tree: return 1
        case .car: return 3
        case .house: return 7
        case .block: return 12
        }
    }
    public var label: String {
        switch self {
        case .tree: return "Tree"
        case .car: return "Car"
        case .house: return "House"
        case .block: return "Building"
        }
    }
}

public struct WorldObject: Identifiable, Sendable {
    public let id: Int
    public let kind: ObjectKind
    public let position: Point
    public var damage: Double = 0
    public var destroyed = false
}

public enum Upgrade: String, CaseIterable, Codable, Identifiable, Sendable {
    case suction, stability, speed
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var detail: String {
        switch self {
        case .suction: return "Lift heavier objects at lower strength. +10% lifting power per rank."
        case .stability: return "Lose less energy in cool, dry air. 14% less loss per rank."
        case .speed: return "Move faster across the map. +12% movement per rank."
        }
    }
    // Existing rank 1–3 purchases and their effects remain unchanged in saved games.
    public static let maxRank = 5
    private static let prices = [60, 130, 200, 450, 900]
    public static func cost(rank: Int) -> Int { prices[min(max(0, rank), prices.count - 1)] }
}

public struct Progress: Codable, Equatable, Sendable {
    public var coins = 0
    public var completedLevels: Set<String> = []
    public var claimedQuests: Set<String> = []
    public var upgrades: [String: Int] = [:]
    public init() {}
    public func rank(_ upgrade: Upgrade) -> Int { min(Upgrade.maxRank, max(0, upgrades[upgrade.rawValue, default: 0])) }
    @discardableResult public mutating func purchase(_ upgrade: Upgrade) -> Bool {
        let current = rank(upgrade)
        let cost = Upgrade.cost(rank: current)
        guard current < Upgrade.maxRank, coins >= cost else { return false }
        coins -= cost
        upgrades[upgrade.rawValue] = current + 1
        return true
    }
    @discardableResult public mutating func awardQuest(_ id: String, amount: Int) -> Int {
        guard claimedQuests.insert(id).inserted else { return 0 }
        coins += amount
        return amount
    }
    @discardableResult public mutating func complete(_ level: Level) -> Int {
        let first = completedLevels.insert(level.id).inserted
        let reward = first ? level.reward : level.reward / 4
        coins += reward
        return reward
    }
}

public enum QuestKind: String, CaseIterable, Sendable { case strength, destruction, survival }
public struct Quest: Identifiable, Sendable {
    public let kind: QuestKind
    public let target: Int
    public var id: String { kind.rawValue }
    public var title: String {
        switch kind {
        case .strength: return "Reach EF\(target)"
        case .destruction: return "Destroy \(target) objects"
        case .survival: return "Survive \(target) seconds"
        }
    }
    public var bonus: Int { 20 }
}

/// Which object types fill each cluster of 15. Slot patterns repeat every five objects.
public enum ObjectMix: Sendable {
    case suburban, mixed, urban
    public func kind(slot: Int) -> ObjectKind {
        let slots: [ObjectKind]
        switch self {
        case .suburban: slots = [.tree, .tree, .car, .house, .house]
        case .mixed: slots = [.tree, .tree, .car, .house, .block]
        case .urban: slots = [.tree, .car, .house, .block, .block]
        }
        return slots[slot % 5]
    }
}

/// Per-city difficulty levers. The defaults describe Moore's calm, static introductory weather.
public struct Tuning: Sendable {
    /// How far weather zones wander, in world units. Zero keeps the weather still.
    public var drift = 0.0
    /// Seconds for one full weather cycle.
    public var driftPeriod = 90.0
    /// Seconds without steering before warm air stops feeding the tornado. Zero disables the penalty.
    public var campDelay = 0.0
    /// Fraction of the city's growth rate earned in mixed air.
    public var mixedGrowth = 0.22
    /// Energy lost per second in mixed air (on top of the growth fraction above).
    public var mixedLoss = 0.0
    /// Multiplier on the energy cost of destroying houses and buildings.
    public var debris = 0.5
    /// Multiplier on the lifting power every object requires.
    public var resistance = 1.0
    /// Size multipliers for warm and dry weather zones.
    public var warmScale = 1.0
    public var dryScale = 1.0
    public var mix = ObjectMix.suburban
}

public struct WeatherZone: Sendable {
    public let center: Point
    public let radius: Double
    public let favorable: Bool
}

public struct Level: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let state: String
    public let difficulty: String
    public let center: Coordinate
    public let latitudeSpan: Double
    public let longitudeSpan: Double
    public let growth: Double
    public let loss: Double
    public let reward: Int
    public let quests: [Quest]
    /// Cluster reference points; nearby objects are illustrative, not parcel data.
    public let anchors: [Coordinate]
    public let tuning: Tuning
    public static let worldSize = Point(1100, 1500)
    public var zones: [WeatherZone] {
        let base = [
            WeatherZone(center: Point(350, 470), radius: 340, favorable: true),
            WeatherZone(center: Point(820, 1100), radius: 310, favorable: true),
            WeatherZone(center: Point(880, 400), radius: 235, favorable: false),
            WeatherZone(center: Point(250, 1160), radius: 240, favorable: false),
        ]
        return base.map { zone in
            WeatherZone(
                center: zone.center,
                radius: zone.radius * (zone.favorable ? tuning.warmScale : tuning.dryScale),
                favorable: zone.favorable)
        }
    }
    /// Eight cluster reference points laid out around a city centre. Flipping the layout gives
    /// each city a different arrangement relative to its warm and dry weather.
    static func cityAnchors(_ center: Coordinate, flipLatitude: Bool = false, flipLongitude: Bool = false)
        -> [Coordinate]
    {
        let offsets: [(Double, Double)] = [
            (-0.0065, -0.0065), (-0.0045, -0.0005), (-0.0005, -0.0075), (0.0010, -0.0005),
            (0.0045, 0.0035), (0.0075, 0.0065), (-0.0055, 0.0065), (0.0005, 0.0065),
        ]
        return offsets.map { latitude, longitude in
            Coordinate(
                center.latitude + (flipLatitude ? -latitude : latitude),
                center.longitude + (flipLongitude ? -longitude : longitude))
        }
    }
    public var start: Point { Point(350, 470) }
    public func point(for coordinate: Coordinate) -> Point {
        Point(
            (coordinate.longitude - center.longitude) / longitudeSpan * Self.worldSize.x + Self.worldSize.x / 2,
            (coordinate.latitude - center.latitude) / latitudeSpan * Self.worldSize.y + Self.worldSize.y / 2)
    }
    public static let all: [Level] = [
        Level(
            id: "moore", name: "Moore", state: "Oklahoma", difficulty: "Easy",
            center: Coordinate(35.3395, -97.4867), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 1.65, loss: 1.8, reward: 200,
            quests: [
                Quest(kind: .strength, target: 2), Quest(kind: .destruction, target: 18),
                Quest(kind: .survival, target: 60),
            ],
            anchors: [
                Coordinate(35.3320, -97.4920), Coordinate(35.3338, -97.4866),
                Coordinate(35.3396, -97.4940), Coordinate(35.3396, -97.4866),
                Coordinate(35.3440, -97.4866), Coordinate(35.3460, -97.4800),
                Coordinate(35.3350, -97.4800), Coordinate(35.3410, -97.4800),
            ],
            tuning: Tuning()),
        Level(
            id: "dallas", name: "Dallas", state: "Texas", difficulty: "Medium",
            center: Coordinate(32.7835, -96.7985), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 1.3, loss: 2.6, reward: 320,
            quests: [
                Quest(kind: .strength, target: 3), Quest(kind: .destruction, target: 28),
                Quest(kind: .survival, target: 85),
            ],
            anchors: [
                Coordinate(32.7770, -96.8050), Coordinate(32.7790, -96.7990),
                Coordinate(32.7830, -96.8060), Coordinate(32.7845, -96.7990),
                Coordinate(32.7880, -96.7950), Coordinate(32.7910, -96.7920),
                Coordinate(32.7780, -96.7920), Coordinate(32.7840, -96.7920),
            ],
            tuning: Tuning(drift: 215, driftPeriod: 95, campDelay: 14, debris: 1, mix: .mixed)),
        Level(
            id: "chicago", name: "Chicago", state: "Illinois", difficulty: "Hard",
            center: Coordinate(41.8870, -87.6320), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 1.0, loss: 3.3, reward: 440,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 38),
                Quest(kind: .survival, target: 100),
            ],
            anchors: [
                Coordinate(41.8790, -87.6380), Coordinate(41.8810, -87.6330),
                Coordinate(41.8860, -87.6390), Coordinate(41.8870, -87.6320),
                Coordinate(41.8920, -87.6310), Coordinate(41.8940, -87.6250),
                Coordinate(41.8810, -87.6250), Coordinate(41.8870, -87.6250),
            ],
            tuning: Tuning(
                drift: 300, driftPeriod: 70, campDelay: 14, mixedGrowth: 0.08, debris: 1.5, mix: .urban)),
        Level(
            id: "wichita", name: "Wichita", state: "Kansas", difficulty: "Expert",
            center: Coordinate(37.6872, -97.3301), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 0.95, loss: 3.5, reward: 580,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 46),
                Quest(kind: .survival, target: 110),
            ],
            anchors: Level.cityAnchors(Coordinate(37.6872, -97.3301), flipLongitude: true),
            tuning: Tuning(
                drift: 330, driftPeriod: 62, campDelay: 12, mixedGrowth: 0.05, mixedLoss: 0.35,
                debris: 1.8, warmScale: 0.95, dryScale: 1.05, mix: .mixed)),
        Level(
            id: "joplin", name: "Joplin", state: "Missouri", difficulty: "Brutal",
            center: Coordinate(37.0842, -94.5133), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 0.90, loss: 3.7, reward: 740,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 54),
                Quest(kind: .survival, target: 120),
            ],
            anchors: Level.cityAnchors(Coordinate(37.0842, -94.5133), flipLatitude: true),
            tuning: Tuning(
                drift: 360, driftPeriod: 58, campDelay: 10, mixedGrowth: 0, mixedLoss: 0.55,
                debris: 2.0, resistance: 1.05, warmScale: 0.92, dryScale: 1.10, mix: .mixed)),
        Level(
            id: "nashville", name: "Nashville", state: "Tennessee", difficulty: "Extreme",
            center: Coordinate(36.1627, -86.7816), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 0.88, loss: 3.9, reward: 920,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 60),
                Quest(kind: .survival, target: 130),
            ],
            anchors: Level.cityAnchors(
                Coordinate(36.1627, -86.7816), flipLatitude: true, flipLongitude: true),
            tuning: Tuning(
                drift: 390, driftPeriod: 54, campDelay: 9, mixedGrowth: 0, mixedLoss: 0.65,
                debris: 2.2, resistance: 1.08, warmScale: 0.90, dryScale: 1.12, mix: .mixed)),
        Level(
            id: "atlanta", name: "Atlanta", state: "Georgia", difficulty: "Nightmare",
            center: Coordinate(33.7490, -84.3880), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 0.85, loss: 4.1, reward: 1120,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 66),
                Quest(kind: .survival, target: 140),
            ],
            anchors: Level.cityAnchors(Coordinate(33.7490, -84.3880)),
            tuning: Tuning(
                drift: 410, driftPeriod: 52, campDelay: 8, mixedGrowth: 0, mixedLoss: 0.75,
                debris: 2.4, resistance: 1.10, warmScale: 0.88, dryScale: 1.15, mix: .urban)),
        Level(
            id: "newyork", name: "New York", state: "New York", difficulty: "Legendary",
            center: Coordinate(40.7580, -73.9855), latitudeSpan: 0.021, longitudeSpan: 0.023,
            growth: 0.82, loss: 4.3, reward: 1360,
            quests: [
                Quest(kind: .strength, target: 5), Quest(kind: .destruction, target: 72),
                Quest(kind: .survival, target: 150),
            ],
            anchors: Level.cityAnchors(Coordinate(40.7580, -73.9855), flipLongitude: true),
            tuning: Tuning(
                drift: 430, driftPeriod: 50, campDelay: 7, mixedGrowth: 0, mixedLoss: 0.85,
                debris: 2.6, resistance: 1.12, warmScale: 0.85, dryScale: 1.20, mix: .urban)),
    ]
}
