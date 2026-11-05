import XCTest

@testable import TornadoCore

final class SimulationTests: XCTestCase {
    func testDisplayedWindMatchesEveryEFCategory() {
        let bands = [65...85, 86...110, 111...135, 136...165, 166...200, 201...220]
        // Moore's calm weather lets us check all six wind categories without fronts.
        var sim = Simulation(level: Level.all[0])
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
    func testWeatherMovesOnlyInHarderCitiesAndTracksElapsedTime() {
        for level in Level.all {
            var sim = Simulation(level: level)
            let start = sim.weatherZones.map(\.center)
            for _ in 0..<260 {
                _ = sim.step(delta: 0.1, direction: Point(0, 0))
            }
            let now = sim.weatherZones.map(\.center)
            if level.id == "moore" {
                XCTAssertEqual(now, start)
            } else {
                XCTAssertNotEqual(now, start, "\(level.name) should have drifting fronts")
            }
        }
    }
    func testCampingInDallasDoesNotBuildStrengthLikeMoving() {
        let level = Level.all[1]
        var stationary = Simulation(level: level)
        var active = Simulation(level: level)
        for frame in 0..<500 {
            _ = stationary.step(delta: 0.1, direction: Point(0, 0))
            let direction = (frame / 10) % 2 == 0 ? Point(1, 0) : Point(-1, 0)
            _ = active.step(delta: 0.1, direction: direction)
        }
        XCTAssertGreaterThan(active.energy, stationary.energy + 10)
    }
    func testHoldingJoystickAgainstBoundaryStillCountsAsCamping() {
        // This edge is inside warm air; neither copy can move farther west.
        let level = customLevel(Tuning(campDelay: 1))
        var blocked = Simulation(level: level)
        for _ in 0..<30 { _ = blocked.step(delta: 0.1, direction: Point(-1, 0)) }
        XCTAssertEqual(blocked.position.x, 24)
        XCTAssertEqual(blocked.weather, .warm)
        var released = blocked
        for _ in 0..<40 {
            _ = blocked.step(delta: 0.1, direction: Point(-1, 0))
            _ = released.step(delta: 0.1, direction: Point(0, 0))
        }
        XCTAssertEqual(blocked.position, released.position)
        XCTAssertEqual(blocked.energy, released.energy, accuracy: 1e-9)
        let before = blocked.energy
        _ = blocked.step(delta: 0.1, direction: Point(-1, 0))
        XCTAssertEqual(blocked.energy - before, level.growth * 0.12 * 0.1, accuracy: 1e-9)
        // Moving along the boundary must release the camping penalty again.
        let beforeMoving = blocked.energy
        _ = blocked.step(delta: 0.1, direction: Point(0, 1))
        XCTAssertEqual(blocked.energy - beforeMoving, level.growth * 0.1, accuracy: 1e-9)
    }
    func testChicagoRequiresEF5AndCampingCannotWin() {
        let level = Level.all[2]
        XCTAssertEqual(level.quests.first(where: { $0.kind == .strength })?.target, 5)
        var sim = Simulation(level: level)
        for _ in 0..<1000 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
        XCTAssertLessThan(sim.peakEF, 5)
        XCTAssertFalse(sim.finished)
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
        var progress = TornadoCore.Progress()
        progress.upgrades[Upgrade.stability.rawValue] = 3
        var base = Simulation(level: Level.all[0])
        var stable = Simulation(level: Level.all[0], progress: progress)
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
        var progress = TornadoCore.Progress()
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
        for _ in 0..<1700 {
            _ = sim.step(delta: 0.1, direction: vector(from: sim.position, to: bestWarmPoint(sim)))
        }
        var occurrences = 0
        for _ in 0..<160 {
            let result = sim.step(delta: 0.1, direction: vector(from: sim.position, to: block.position))
            occurrences += result.destroyed.filter { $0 == block.id }.count
        }
        XCTAssertTrue(sim.objects[block.id].destroyed)
        XCTAssertEqual(occurrences, 1)
    }
    func testSuctionImprovesLiftWithoutChangingEF() {
        var progress = TornadoCore.Progress()
        progress.upgrades[Upgrade.suction.rawValue] = 3
        let base = Simulation(level: Level.all[0])
        let upgraded = Simulation(level: Level.all[0], progress: progress)
        XCTAssertEqual(base.ef, upgraded.ef)
        XCTAssertGreaterThan(upgraded.liftingPower, base.liftingPower)
    }
    func testEveryLevelIsCompletableWithActualMovementAndDestruction() {
        for level in Level.all {
            var sim = Simulation(level: level)
            var destroyedKinds: Set<ObjectKind> = []
            // Pursue the best warm air, as a player would, so the tougher cities grow naturally.
            // Destruction during this phase counts too: some cities can finish while chasing warm air.
            for _ in 0..<1700 {
                let result = sim.step(delta: 0.1, direction: vector(from: sim.position, to: bestWarmPoint(sim)))
                for id in result.destroyed { destroyedKinds.insert(sim.objects[id].kind) }
            }
            for _ in 0..<12000 {
                if sim.finished || sim.dissipated { break }
                let target: Point
                if sim.energy < 78 {
                    target = bestWarmPoint(sim)
                } else if let next = sim.objects.filter({ !$0.destroyed && sim.requiredPower(for: $0) <= sim.liftingPower })
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
    func testEightCitiesRampUpInEveryWay() {
        let levels = Level.all
        XCTAssertEqual(levels.count, 8)
        XCTAssertEqual(Set(levels.map(\.id)).count, levels.count)
        XCTAssertEqual(
            levels.map(\.difficulty),
            ["Easy", "Medium", "Hard", "Expert", "Brutal", "Extreme", "Nightmare", "Legendary"])
        for (easier, harder) in zip(levels, levels.dropFirst()) {
            XCTAssertGreaterThan(harder.reward, easier.reward, harder.name)
            XCTAssertLessThanOrEqual(harder.growth, easier.growth, harder.name)
            XCTAssertGreaterThanOrEqual(harder.loss, easier.loss, harder.name)
            XCTAssertGreaterThanOrEqual(harder.tuning.debris, easier.tuning.debris, harder.name)
            XCTAssertGreaterThanOrEqual(harder.tuning.drift, easier.tuning.drift, harder.name)
            XCTAssertLessThanOrEqual(harder.tuning.warmScale, easier.tuning.warmScale, harder.name)
            for kind in QuestKind.allCases {
                let before = easier.quests.first { $0.kind == kind }!.target
                let after = harder.quests.first { $0.kind == kind }!.target
                XCTAssertGreaterThanOrEqual(after, before, "\(harder.name) \(kind)")
            }
        }
        for level in levels.dropFirst(2) {
            XCTAssertEqual(level.quests.first { $0.kind == .strength }?.target, 5, level.name)
        }
    }
    func testNoHardCityCanBeWonByCamping() {
        for level in Level.all.dropFirst(2) {
            var sim = Simulation(level: level)
            for _ in 0..<1000 { _ = sim.step(delta: 0.1, direction: Point(0, 0)) }
            XCTAssertLessThan(sim.peakEF, 5, level.name)
            XCTAssertFalse(sim.finished, level.name)
        }
    }
    func testLaterCitiesDemandMoreLiftingPower() {
        let moore = Simulation(level: Level.all[0])
        let newYork = Simulation(level: Level.all[7])
        let block = newYork.objects.first { $0.kind == .block }!
        XCTAssertEqual(moore.requiredPower(for: block), ObjectKind.block.resistance)
        XCTAssertGreaterThan(newYork.requiredPower(for: block), ObjectKind.block.resistance)
        XCTAssertLessThan(newYork.requiredPower(for: block), 100, "EF5 must still be able to lift it")
    }
    func testOriginalThreeCitiesKeepTheirTuning() {
        let moore = Level.all[0].tuning
        XCTAssertEqual(moore.drift, 0)
        XCTAssertEqual(moore.campDelay, 0)
        XCTAssertEqual(moore.mixedLoss, 0)
        XCTAssertEqual(moore.debris, 0.5)
        let dallas = Level.all[1].tuning
        XCTAssertEqual(dallas.drift, 215)
        XCTAssertEqual(dallas.driftPeriod, 95)
        XCTAssertEqual(dallas.campDelay, 14)
        XCTAssertEqual(dallas.debris, 1)
        let chicago = Level.all[2].tuning
        XCTAssertEqual(chicago.drift, 300)
        XCTAssertEqual(chicago.driftPeriod, 70)
        XCTAssertEqual(chicago.mixedGrowth, 0.08)
        XCTAssertEqual(chicago.debris, 1.5)
    }
    func testEveryCityStartsInWarmAirAndHasEnoughObjectsForItsQuest() {
        for level in Level.all {
            let sim = Simulation(level: level)
            XCTAssertEqual(sim.weather, .warm, level.name)
            let target = level.quests.first { $0.kind == .destruction }!.target
            let reachable = sim.objects.filter { sim.requiredPower(for: $0) < 100 }.count
            XCTAssertGreaterThan(reachable, target + 20, level.name)
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
    func testHotAndHotBubblesMakeSuperHotAir() {
        let a = WeatherZone(center: Point(0, 0), radius: 10, favorable: true)
        let b = WeatherZone(center: Point(12, 0), radius: 10, favorable: true)
        XCTAssertEqual(Simulation.weather(at: Point(6, 0), in: [a, b]), .superWarm)
        XCTAssertEqual(Simulation.weather(at: Point(-5, 0), in: [a, b]), .warm)
        XCTAssertEqual(Simulation.weather(at: Point(17, 0), in: [a, b]), .warm)
    }
    func testColdAndColdBubblesMakeSuperColdAir() {
        let a = WeatherZone(center: Point(0, 0), radius: 10, favorable: false)
        let b = WeatherZone(center: Point(12, 0), radius: 10, favorable: false)
        XCTAssertEqual(Simulation.weather(at: Point(6, 0), in: [a, b]), .superDry)
        XCTAssertEqual(Simulation.weather(at: Point(-5, 0), in: [a, b]), .dry)
    }
    func testHotAndColdBubblesMakeMixedAirEvenWithAThirdBubble() {
        let hot = WeatherZone(center: Point(0, 0), radius: 10, favorable: true)
        let cold = WeatherZone(center: Point(12, 0), radius: 10, favorable: false)
        let hot2 = WeatherZone(center: Point(0, 3), radius: 10, favorable: true)
        XCTAssertEqual(Simulation.weather(at: Point(6, 0), in: [hot, cold]), .mixed)
        XCTAssertEqual(Simulation.weather(at: Point(6, 0), in: [hot, hot2, cold]), .mixed)
        XCTAssertEqual(Simulation.weather(at: Point(50, 50), in: [hot, cold]), .mixed)
    }
    func testOverlapRegionsDescribeTheSharedLens() {
        let a = WeatherZone(center: Point(0, 0), radius: 10, favorable: true)
        let b = WeatherZone(center: Point(12, 0), radius: 10, favorable: false)
        let far = WeatherZone(center: Point(100, 0), radius: 5, favorable: true)
        let overlaps = Simulation.overlaps(of: [a, b, far])
        XCTAssertEqual(overlaps.count, 1)
        let lens = overlaps[0]
        XCTAssertEqual(lens.outcome, .mixed)
        XCTAssertEqual(lens.center.x, 6, accuracy: 1e-9)
        XCTAssertEqual(lens.halfLength, 4, accuracy: 1e-9)
        XCTAssertEqual(lens.halfWidth, 8, accuracy: 1e-9)
        let inner = WeatherZone(center: Point(2, 0), radius: 3, favorable: true)
        let nested = Simulation.overlaps(of: [a, inner])
        XCTAssertEqual(nested.first?.outcome, .superWarm)
        XCTAssertEqual(nested.first?.halfLength, 3)
        XCTAssertEqual(nested.first?.center, inner.center)
    }
    func testWarmAndColdOverlapInsideMooreIsMixedNotWarm() {
        var sim = Simulation(level: Level.all[0])
        XCTAssertTrue(sim.weatherOverlaps.contains { $0.outcome == .mixed })
        // The lens between Moore's first warm and first cold bubble.
        steer(&sim, to: Point(667, 428), steps: 40)
        XCTAssertEqual(sim.weather, .mixed)
    }
    func testOverlappingHotBubblesFeedTheTornadoFaster() {
        let level = customLevel(Tuning(warmScale: 1.6))
        var sim = Simulation(level: level)
        steer(&sim, to: Point(599, 804), steps: 40)
        XCTAssertEqual(sim.weather, .superWarm)
        let before = sim.energy
        _ = sim.step(delta: 0.1, direction: Point(0, 0))
        XCTAssertEqual(sim.energy - before, level.growth * Simulation.superWarmBoost * 0.1, accuracy: 1e-9)
    }
    func testOverlappingColdBubblesDrainTheTornadoFaster() {
        let level = customLevel(Tuning(dryScale: 2.2))
        var sim = Simulation(level: level)
        steer(&sim, to: Point(569, 776), steps: 40)
        XCTAssertEqual(sim.weather, .superDry)
        XCTAssertGreaterThan(sim.energy, 1)
        let before = sim.energy
        _ = sim.step(delta: 0.1, direction: Point(0, 0))
        XCTAssertEqual(sim.energy - before, -level.loss * Simulation.superDryPenalty * 0.1, accuracy: 1e-9)
    }
    func testStabilityAlsoSoftensSuperColdAir() {
        var progress = TornadoCore.Progress()
        progress.upgrades[Upgrade.stability.rawValue] = 3
        let level = customLevel(Tuning(dryScale: 2.2))
        var base = Simulation(level: level)
        var stable = Simulation(level: level, progress: progress)
        steer(&base, to: Point(569, 776), steps: 40)
        steer(&stable, to: Point(569, 776), steps: 40)
        let baseBefore = base.energy
        let stableBefore = stable.energy
        _ = base.step(delta: 0.1, direction: Point(0, 0))
        _ = stable.step(delta: 0.1, direction: Point(0, 0))
        XCTAssertGreaterThan(stable.energy - stableBefore, base.energy - baseBefore)
    }
    private func customLevel(_ tuning: Tuning) -> Level {
        let base = Level.all[0]
        return Level(
            id: "test", name: "Test", state: "Test", difficulty: "Easy", center: base.center,
            latitudeSpan: base.latitudeSpan, longitudeSpan: base.longitudeSpan, growth: base.growth,
            loss: base.loss, reward: base.reward, quests: base.quests, anchors: base.anchors, tuning: tuning)
    }
    /// A player's choice of air: the warm-bubble point with the best weather, then the closest one.
    private func bestWarmPoint(_ sim: Simulation) -> Point {
        let rank: [Weather: Int] = [.superWarm: 3, .warm: 2, .mixed: 1, .dry: 0, .superDry: -1]
        let zones = sim.weatherZones
        var best = zones[0].center
        var bestRank = Int.min
        var bestDistance = Double.infinity
        for zone in zones where zone.favorable {
            var points = [zone.center]
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                points.append(
                    Point(
                        min(max(30, zone.center.x + cos(angle) * zone.radius * 0.5), Level.worldSize.x - 30),
                        min(max(30, zone.center.y + sin(angle) * zone.radius * 0.5), Level.worldSize.y - 30)))
            }
            for point in points {
                let pointRank = rank[Simulation.weather(at: point, in: zones)]!
                let distance = sim.position.distance(to: point)
                if pointRank > bestRank || (pointRank == bestRank && distance < bestDistance) {
                    best = point
                    bestRank = pointRank
                    bestDistance = distance
                }
            }
        }
        return best
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

