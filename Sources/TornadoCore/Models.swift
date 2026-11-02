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
    /// Real street/park reference points; nearby objects are illustrative, not parcel data.
    public let anchors: [Coordinate]
    public static let worldSize = Point(1100, 1500)
    public var zones: [WeatherZone] {
        [
            WeatherZone(center: Point(350, 470), radius: 340, favorable: true),
            WeatherZone(center: Point(820, 1100), radius: 310, favorable: true),
            WeatherZone(center: Point(880, 400), radius: 235, favorable: false),
            WeatherZone(center: Point(250, 1160), radius: 240, favorable: false),
        ]
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
            ]),
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
            ]),
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
            ]),
    ]
}
