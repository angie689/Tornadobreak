import Combine
import Foundation
import TornadoCore

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var progress: Progress
    private let defaults: UserDefaults
    private let key = "tornadobreak.progress.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(Progress.self, from: data) {
            var sanitized = saved
            sanitized.coins = max(0, saved.coins)
            progress = sanitized
        } else {
            progress = Progress()
        }
    }
    func purchase(_ upgrade: Upgrade) {
        var next = progress
        if next.purchase(upgrade) { commit(next) }
    }
    /// All rewards from a frame are saved together, before any result screen appears.
    func record(_ result: StepResult, simulation: Simulation) -> (coins: Int, completion: Int) {
        guard !result.destroyed.isEmpty || !result.newQuests.isEmpty || result.finished else { return (0, 0) }
        var next = progress
        let before = next.coins
        for id in result.destroyed {
            next.coins += simulation.objects[id].kind.coins
        }
        for kind in result.newQuests {
            if let quest = simulation.level.quests.first(where: { $0.kind == kind }) {
                next.awardQuest("\(simulation.level.id).\(kind.rawValue)", amount: quest.bonus)
            }
        }
        let completion = result.finished ? next.complete(simulation.level) : 0
        if next != progress { commit(next) }
        return (next.coins - before, completion)
    }
    private func commit(_ value: Progress) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
        progress = value
    }
}

