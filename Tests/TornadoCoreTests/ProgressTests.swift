import XCTest

@testable import TornadoCore

final class ProgressTests: XCTestCase {
    func testCompletionPaysFullOnceThenQuarter() {
        for level in Level.all {
            var progress = TornadoCore.Progress()
            XCTAssertEqual(progress.complete(level), level.reward)
            XCTAssertEqual(progress.complete(level), level.reward / 4)
            XCTAssertEqual(progress.complete(level), level.reward / 4)
            XCTAssertEqual(progress.completedLevels.count, 1)
            XCTAssertEqual(progress.coins, level.reward + level.reward / 2)
        }
    }
    func testQuestsAreOneTimeAndSurviveSerialization() throws {
        var progress = TornadoCore.Progress()
        XCTAssertEqual(progress.awardQuest("moore.strength", amount: 20), 20)
        let data = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(TornadoCore.Progress.self, from: data)
        XCTAssertEqual(restored.awardQuest("moore.strength", amount: 20), 0)
        XCTAssertEqual(restored.awardQuest("dallas.strength", amount: 20), 20)
        XCTAssertEqual(restored.coins, 40)
    }
    func testExistingThreeRankSaveCanPurchaseNewRanks() throws {
        var oldSave = TornadoCore.Progress()
        oldSave.upgrades["suction"] = 3
        oldSave.coins = 1350
        var restored = try JSONDecoder().decode(
            TornadoCore.Progress.self, from: JSONEncoder().encode(oldSave))
        XCTAssertEqual(restored.rank(.suction), 3)
        XCTAssertEqual(Upgrade.cost(rank: 3), 450)
        XCTAssertEqual(Upgrade.cost(rank: 4), 900)
        XCTAssertTrue(restored.purchase(.suction))
        XCTAssertTrue(restored.purchase(.suction))
        XCTAssertEqual(restored.rank(.suction), 5)
        XCTAssertEqual(restored.coins, 0)
    }

    func testTwoCitiesCannotFundEveryUpgradeEvenIfEveryObjectIsDestroyed() {
        let earlyLevels = Array(Level.all.prefix(2))
        let maxEarlyIncome = earlyLevels.reduce(0) { subtotal, level in
            subtotal + Simulation(level: level).objects.reduce(0) { $0 + $1.kind.coins }
                + level.reward + level.quests.reduce(0) { $0 + $1.bonus }
        }
        let fullUpgradeCost = Upgrade.allCases.count *
            (0..<Upgrade.maxRank).reduce(0) { $0 + Upgrade.cost(rank: $1) }
        XCTAssertLessThan(maxEarlyIncome, fullUpgradeCost)
    }

    func testPurchasesAreAffordablePermanentAndCapped() throws {
        var progress = TornadoCore.Progress()
        XCTAssertFalse(progress.purchase(.suction))
        progress.coins = 5000
        for _ in 0..<Upgrade.maxRank { XCTAssertTrue(progress.purchase(.suction)) }
        XCTAssertEqual(progress.coins, 3260)
        XCTAssertEqual(progress.rank(.suction), 5)
        XCTAssertFalse(progress.purchase(.suction))
        let restored = try JSONDecoder().decode(TornadoCore.Progress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.rank(.speed), 0)
    }
}
