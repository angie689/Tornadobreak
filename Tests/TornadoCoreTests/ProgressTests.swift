import XCTest
@testable import TornadoCore

final class ProgressTests: XCTestCase {
    func testCompletionPaysFullOnceThenQuarter() {
        for level in Level.all {
            var progress = Progress()
            XCTAssertEqual(progress.complete(level), level.reward)
            XCTAssertEqual(progress.complete(level), level.reward / 4)
            XCTAssertEqual(progress.complete(level), level.reward / 4)
            XCTAssertEqual(progress.completedLevels.count, 1)
            XCTAssertEqual(progress.coins, level.reward + level.reward / 2)
        }
    }
    func testQuestsAreOneTimeAndSurviveSerialization() throws {
        var progress = Progress()
        XCTAssertEqual(progress.awardQuest("moore.strength", amount: 20), 20)
        let data = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(Progress.self, from: data)
        XCTAssertEqual(restored.awardQuest("moore.strength", amount: 20), 0)
        XCTAssertEqual(restored.awardQuest("dallas.strength", amount: 20), 20)
        XCTAssertEqual(restored.coins, 40)
    }
    func testPurchasesAreAffordablePermanentAndCapped() throws {
        var progress = Progress()
        XCTAssertFalse(progress.purchase(.suction))
        progress.coins = 1000
        for _ in 0..<3 { XCTAssertTrue(progress.purchase(.suction)) }
        XCTAssertEqual(progress.coins, 610)
        XCTAssertEqual(progress.rank(.suction), 3)
        XCTAssertFalse(progress.purchase(.suction))
        let restored = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.rank(.speed), 0)
    }
}
