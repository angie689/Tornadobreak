import SpriteKit
import TornadoCore
import XCTest

@testable import Tornadobreak

final class AppTests: XCTestCase {
    func testObjectsVisiblyLiftBeforeDestruction() async throws {
        try await MainActor.run {
            let scene = TornadoScene(level: Level.all[0], progress: TornadoCore.Progress())
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 896, height: 414))
            view.presentScene(scene)
            defer { scene.stop() }
            let target = try XCTUnwrap(scene.simulation.objects.first { $0.kind == .tree })
            scene.update(0)
            var lifted = false
            for frame in 1...240 {
                let position = scene.simulation.position
                let distance = position.distance(to: target.position)
                scene.setDirection(distance > 4
                    ? Point((target.position.x - position.x) / distance, (target.position.y - position.y) / distance)
                    : Point(0, 0))
                scene.update(Double(frame) / 60)
                let object = scene.simulation.objects[target.id]
                if object.damage > 0 && !object.destroyed {
                    let node = try XCTUnwrap(scene.childNode(withName: "//object-\(target.id)"))
                    XCTAssertGreaterThan(node.xScale, 1)
                    XCTAssertNotEqual(node.position, CGPoint(x: target.position.x, y: target.position.y))
                    lifted = true
                    break
                }
            }
            XCTAssertTrue(lifted)
        }
    }
    func testCustomCarAndTreeArtIsBundled() async {
        await MainActor.run {
            for name in ["CarGray", "CarBlue", "CarRed", "CarWhite", "Tree"] {
                XCTAssertNotNil(UIImage(named: name), "Missing sprite: \(name)")
            }
        }
    }
    func testAnimatedTornadoVortexAtlasIsBundled() async {
        await MainActor.run {
            let atlas = UIImage(named: "TornadoVortexAtlas")
            XCTAssertNotNil(atlas)
            if let atlas {
                XCTAssertEqual(atlas.size.width / atlas.size.height, 8, accuracy: 0.05)
            }
            let scene = TornadoScene(level: Level.all[0], progress: TornadoCore.Progress())
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 896, height: 414))
            view.presentScene(scene)
            XCTAssertNotNil(scene.childNode(withName: "//vortexSprite"))
            scene.stop()
        }
    }
    func testOnlyLandscapeOrientationsAreSupported() {
        let orientations = Bundle(for: TornadoScene.self)
            .object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String]
        XCTAssertEqual(
            Set(orientations ?? []),
            Set(["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
        )
    }
    func testSceneBuildsAndUpdatesActualTornado() async {
        await MainActor.run {
            let scene = TornadoScene(level: Level.all[0], progress: TornadoCore.Progress())
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 896, height: 414))
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

