import SpriteKit
import TornadoCore
import XCTest

@testable import Tornadobreak

final class AppTests: XCTestCase {
    func testSceneBuildsAndUpdatesActualTornado() async {
        await MainActor.run {
            let scene = TornadoScene(level: Level.all[0], progress: Progress())
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 414, height: 896))
            view.presentScene(scene)
            XCTAssertGreaterThan(scene.children.count, 4)
            let start = scene.simulation.position
            scene.setDirection(Point(1, 0))
            scene.update(1)
            scene.update(1.05)
            XCTAssertGreaterThan(scene.simulation.position.x, start.x)
            scene.stop()
        }
    }
    func testPauseFreezesSimulationAndResumeResetsClock() async {
        await MainActor.run {
            let session = GameSession(level: Level.all[0], store: ProgressStore())
            let scene = session.scene
            scene.update(1)
            scene.update(1.05)
            let elapsed = scene.simulation.elapsed
            session.setPaused(true)
            scene.update(100)
            scene.update(101)
            XCTAssertEqual(scene.simulation.elapsed, elapsed)
            session.setPaused(false)
            scene.update(102)
            XCTAssertEqual(scene.simulation.elapsed, elapsed)
            scene.update(102.02)
            XCTAssertGreaterThan(scene.simulation.elapsed, elapsed)
            scene.stop()
        }
    }
    func testProgressStoreSavesRewardsAndPurchasesImmediately() async throws {
        try await MainActor.run {
            let name = "TornadobreakTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let store = ProgressStore(defaults: defaults)
            let sim = Simulation(level: Level.all[0])
            var result = StepResult()
            result.finished = true
            result.newQuests = [.strength, .destruction, .survival]
            let earned = store.record(result, simulation: sim)
            XCTAssertEqual(earned.completion, 200)
            XCTAssertEqual(store.progress.coins, 260)
            store.purchase(.speed)
            let restored = ProgressStore(defaults: defaults)
            XCTAssertEqual(restored.progress.coins, 200)
            XCTAssertEqual(restored.progress.rank(.speed), 1)
            let replay = restored.record(result, simulation: sim)
            XCTAssertEqual(replay.coins, 50)
            XCTAssertEqual(restored.progress.coins, 250)
        }
    }
}
