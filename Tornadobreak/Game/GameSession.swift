import SwiftUI
import TornadoCore

struct RunSummary {
    let won: Bool
    let coins: Int
    let completion: Int
    let firstCompletion: Bool
    let destroyed: Int
    let peakEF: Int
    let seconds: Int
}

@MainActor
final class GameSession: ObservableObject {
    let level: Level
    let store: ProgressStore
    @Published var simulation: Simulation
    @Published var paused = false
    @Published var summary: RunSummary?
    @Published var mapStatus = "Loading Apple Maps…"
    @Published var toast = "Stay in green air to grow"
    @Published var coins: Int
    private var runCoins = 0
    private let wasCompleted: Bool
    lazy var scene: TornadoScene = {
        let scene = TornadoScene(level: level, progress: store.progress)
        scene.session = self
        return scene
    }()

    init(level: Level, store: ProgressStore) {
        self.level = level; self.store = store
        simulation = Simulation(level: level, progress: store.progress)
        coins = store.progress.coins
        wasCompleted = store.progress.completedLevels.contains(level.id)
    }
    func receive(_ simulation: Simulation, result: StepResult, publishHUD: Bool) {
        let reward = store.record(result, simulation: simulation)
        runCoins += reward.coins
        if !result.newQuests.isEmpty { toast = "Objective complete · progress saved" }
        if publishHUD || result.finished || simulation.dissipated || !result.newQuests.isEmpty {
            self.simulation = simulation
            coins = store.progress.coins
        }
        if result.finished || simulation.dissipated {
            scene.setDirection(Point(0, 0))
            summary = RunSummary(won: result.finished, coins: runCoins, completion: reward.completion,
                                 firstCompletion: !wasCompleted, destroyed: simulation.destroyedCount,
                                 peakEF: simulation.peakEF, seconds: Int(simulation.elapsed))
            scene.isPaused = true
        }
    }
    func setPaused(_ value: Bool) {
        guard summary == nil else { return }
        paused = value
        scene.setDirection(Point(0, 0))
        scene.resetClock()
        scene.isPaused = value
    }
}
