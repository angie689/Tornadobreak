import XCTest

@testable import TornadoCore

final class SimulationTests: XCTestCase {
    func testDisplayedWindMatchesEveryEFCategory() {
        let bands = [65...85, 86...110, 111...135, 136...165, 166...200, 201...220]
        for level in Level.all {
            var sim = Simulation(level: level)
            var categories: Set<Int> = []
            var previousWind = sim.wind
            for _ in 0..<1100 {
                _ = sim.step(delta: 0.1, direction: Point(0, 0))
                categories.insert(sim.ef)
                XCTAssertTrue(bands[sim.ef].contains(sim.wind), "EF\(sim.ef) with \(sim.wind) mph")
                XCTAssertGreaterThanOrEqual(sim.wind, previousWind)
                previousWind = sim.wind
            }
            XCTAssertEqual(categories, Set(0...5))
        }
    }
    func testLiftFeedbackOnlyAppliesToReachableObjects() {
        var sim = Simulation(level: Level.all[0])
        let target = sim.objects.first { $0.kind == .tree }!
        XCTAssertFalse(sim.canLift(target))
        var sawLifting = false
        for _ in 0..<150 {
            _ = sim.step(delta: 0.05, direction: vector(from: sim.position, to: target.position))
            let current = sim.objects[target.id]
            if current.damage > 0 && !current.destroyed {
                XCTAssertTrue(sim.canLift(current))
                sawLifting = true
            }
        }
        XCTAssertTrue(sawLifting)
        XCTAssertTrue(sim.objects[target.id].destroyed)
        XCTAssertFalse(sim.canLift(sim.objects[target.id]))
    }
    func testWarmAirGrowsFromEF0ToEF5AndWidens() {
        var sim = Simulation(level: Level.all[0])
        XCTAssertEqual(sim.ef, 0)
        let initialRadius = sim.radius
        for _ in 0..<600 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
        XCTAssertEqual(sim.ef, 5)
        XCTAssertGreaterThan(sim.radius, initialRadius * 2)
        XCTAssertGreaterThan(sim.wind, 200)
    }
    func testColdAirWeakensAndStabilityReducesLoss() {
        var progress = Progress()
        progress.upgrades[Upgrade.stability.rawValue] = 3
        var base = Simulation(level: Level.all[2])
        var stable = Simulation(level: Level.all[2], progress: progress)
        for _ in 0..<700 {
            _ = base.step(delta: 0.1, direction: Point(0, 0))
            _ = stable.step(delta: 0.1, direction: Point(0, 0))
        }
        steer(&base, to: Point(880, 400), steps: 80)
        steer(&stable, to: Point(880, 400), steps: 80)
        let before = base.energy
        for _ in 0..<30 {
            _ = base.step(delta: 0.1, direction: Point(0, 0))
            _ = stable.step(delta: 0.1, direction: Point(0, 0))
        }
        XCTAssertEqual(base.weather, .dry)
        XCTAssertLessThan(base.energy, before)
        XCTAssertGreaterThan(stable.energy, base.energy)
    }
    func testMovementClampsToWorldAndSpeedUpgradeWorks() {
        var progress = Progress()
        progress.upgrades[Upgrade.speed.rawValue] = 3
        var base = Simulation(level: Level.all[0])
        var fast = Simulation(level: Level.all[0], progress: progress)
        _ = base.step(delta: 0.1, direction: Point(1, 0))
        _ = fast.step(delta: 0.1, direction: Point(1, 0))
        XCTAssertGreaterThan(fast.position.x, base.position.x)
        for _ in 0..<1000 { _ = fast.step(delta: 0.1, direction: Point(-1, -1)) }
        XCTAssertGreaterThanOrEqual(fast.position.x, 24)
        XCTAssertGreaterThanOrEqual(fast.position.y, 24)
        let before = fast.elapsed
        _ = fast.step(delta: .nan, direction: Point(0, 0))
        XCTAssertEqual(fast.elapsed, before)
    }
    func testHeavyBuildingsRequireStrengthAndOnlyPayOnce() {
        let level = Level.all[2]
        var sim = Simulation(level: level)
        let block = sim.objects.first { $0.kind == .block }!
        steer(&sim, to: block.position, steps: 80)
        XCTAssertFalse(sim.objects[block.id].destroyed, "A weak funnel must not lift a block")
        steer(&sim, to: level.start, steps: 80)
        for _ in 0..<950 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
        var occurrences = 0
        for _ in 0..<160 {
            let result = sim.step(delta: 0.1, direction: vector(from: sim.position, to: block.position))
            occurrences += result.destroyed.filter { $0 == block.id }.count
        }
        XCTAssertTrue(sim.objects[block.id].destroyed)
        XCTAssertEqual(occurrences, 1)
    }
    func testSuctionImprovesLiftWithoutChangingEF() {
        var progress = Progress()
        progress.upgrades[Upgrade.suction.rawValue] = 3
        let base = Simulation(level: Level.all[0])
        let upgraded = Simulation(level: Level.all[0], progress: progress)
        XCTAssertEqual(base.ef, upgraded.ef)
        XCTAssertGreaterThan(upgraded.liftingPower, base.liftingPower)
    }
    func testEveryLevelIsCompletableWithActualMovementAndDestruction() {
        for level in Level.all {
            var sim = Simulation(level: level)
            // Grow in the starting warm zone, then seek nearby objects.
            for _ in 0..<950 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
            var destroyedKinds: Set<ObjectKind> = []
            for _ in 0..<12000 {
                if sim.finished || sim.dissipated { break }
                let target: Point
                if sim.energy < 55 {
                    target = level.start
                } else if let next = sim.objects.filter({ !$0.destroyed && $0.kind.resistance <= sim.liftingPower })
                    .min(by: { $0.position.distance(to: sim.position) < $1.position.distance(to: sim.position) })
                {
                    target = next.position
                } else {
                    target = level.start
                }
                let result = sim.step(delta: 0.1, direction: vector(from: sim.position, to: target))
                for id in result.destroyed { destroyedKinds.insert(sim.objects[id].kind) }
            }
            XCTAssertTrue(sim.finished, "\(level.name): EF\(sim.ef), \(sim.destroyedCount) destroyed, \(sim.elapsed)s")
            XCTAssertFalse(sim.dissipated)
            XCTAssertEqual(sim.achieved.count, 3)
            XCTAssertTrue(destroyedKinds.contains(.tree))
            XCTAssertTrue(destroyedKinds.contains(.car))
            XCTAssertTrue(destroyedKinds.contains(.house))
            let count = sim.destroyedCount
            let event = sim.step(delta: 0.1, direction: Point(0, 0))
            XCTAssertFalse(event.finished, "Completion is emitted exactly once")
            XCTAssertEqual(count, sim.destroyedCount)
        }
    }
    func testDissipationStopsTheRun() {
        var sim = Simulation(level: Level.all[2])
        // Cross into dry air while still weak, then stay there.
        steer(&sim, to: Point(880, 400), steps: 60)
        for _ in 0..<600 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
        XCTAssertTrue(sim.dissipated)
        let elapsed = sim.elapsed
        _ = sim.step(delta: 0.1, direction: Point(1, 0))
        XCTAssertEqual(sim.elapsed, elapsed)
    }
    func testObjectsAreDeterministicAndAnchoredInsideEachRegion() {
        for level in Level.all {
            let sim = Simulation(level: level)
            XCTAssertEqual(sim.objects.count, 120)
            XCTAssertEqual(sim.objects.map(\.position), Simulation(level: level).objects.map(\.position))
            for object in sim.objects {
                XCTAssertTrue((0...Level.worldSize.x).contains(object.position.x))
                XCTAssertTrue((0...Level.worldSize.y).contains(object.position.y))
            }
            XCTAssertEqual(level.point(for: level.center), Point(550, 750))
        }
    }
    private func vector(from: Point, to: Point) -> Point {
        let distance = from.distance(to: to)
        guard distance > 4 else { return Point(0, 0) }
        return Point((to.x - from.x) / distance, (to.y - from.y) / distance)
    }
    private func steer(_ sim: inout Simulation, to target: Point, steps: Int) {
        for _ in 0..<steps { _ = sim.step(delta: 0.1, direction: vector(from: sim.position, to: target)) }
    }
}

