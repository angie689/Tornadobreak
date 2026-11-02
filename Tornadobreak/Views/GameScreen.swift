import SpriteKit
import SwiftUI
import TornadoCore

struct GameScreen: View {
    let level: Level
    let store: ProgressStore
    @State private var runID = UUID()
    var body: some View {
        GameRunView(level: level, store: store, replay: { runID = UUID() })
            .id(runID).navigationBarHidden(true).statusBarHidden(true)
    }
}

private struct GameRunView: View {
    @StateObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let replay: () -> Void
    init(level: Level, store: ProgressStore, replay: @escaping () -> Void) {
        _session = StateObject(wrappedValue: GameSession(level: level, store: store))
        self.replay = replay
    }
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            SpriteView(scene: session.scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea().accessibilityLabel("Tornado simulation map")
            VStack(spacing: 0) {
                hud
                Spacer(minLength: 4)
                controls
            }
            if session.paused { pauseOverlay }
            if let summary = session.summary { resultOverlay(summary) }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { session.setPaused(true) }
        }
        .onDisappear { session.scene.stop() }
        .persistentSystemOverlays(.hidden)
    }
    // Compact landscape strip: quests and controls remain visible on short iPhone screens.
    private var hud: some View {
        HStack(alignment: .center, spacing: 9) {
            Button {
                session.setPaused(true)
            } label: {
                Image(systemName: "pause.fill")
                    .font(.subheadline)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Pause")
            .accessibilityIdentifier("pauseButton")

            VStack(alignment: .leading, spacing: 1) {
                Text("EF\(session.simulation.ef)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.mint)
                    .accessibilityIdentifier("strengthLabel")
                Text(session.level.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 94, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(session.simulation.wind) mph")
                        .font(.caption.bold())
                        .monospacedDigit()
                    Text("\(Int(session.simulation.elapsed))s")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
                ProgressView(value: session.simulation.energy, total: 100)
                    .tint(Theme.mint)
                Text(session.simulation.weather.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(weatherColor)
            }
            .frame(width: 130, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(session.level.quests) { quest in
                    let done = session.simulation.achieved.contains(quest.kind)
                    HStack(spacing: 5) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Theme.mint : Theme.muted)
                        Text(quest.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 2)
                        Text("\(min(quest.target, session.simulation.value(for: quest)))/\(quest.target)")
                            .foregroundStyle(Theme.muted)
                            .monospacedDigit()
                    }
                    .font(.system(size: 10, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CoinPill(amount: session.coins)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
    private var weatherColor: Color {
        switch session.simulation.weather {
        case .warm: return Theme.mint
        case .mixed: return .yellow
        case .dry: return .cyan
        }
    }
    private var controls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if session.simulation.energy < 10 && session.simulation.weather == .dry {
                    Text(session.simulation.energy <= 0
                        ? "\(session.simulation.dissipationRemaining)s left · Get to green air!"
                        : "LOW ENERGY · Find green air!")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .padding(6)
                        .background(Theme.background.opacity(0.9), in: Capsule())
                }
                Joystick { session.scene.setDirection($0) }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                miniMap
                Text("N ↑  ·  \(session.mapStatus)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Maps © Apple · Game objects illustrative")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(6)
            .background(Theme.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 5)
    }
    private var miniMap: some View {
        Canvas { context, size in
            let scaleX = size.width / Level.worldSize.x
            let scaleY = size.height / Level.worldSize.y
            for zone in session.level.zones {
                let rect = CGRect(
                    x: (zone.center.x - zone.radius) * scaleX,
                    y: (Level.worldSize.y - zone.center.y - zone.radius) * scaleY,
                    width: zone.radius * 2 * scaleX, height: zone.radius * 2 * scaleY)
                context.fill(Path(ellipseIn: rect), with: .color((zone.favorable ? Theme.mint : .blue).opacity(0.24)))
            }
            let position = session.simulation.position
            let dot = CGRect(
                x: position.x * scaleX - 3, y: (Level.worldSize.y - position.y) * scaleY - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dot), with: .color(.white))
        }.frame(width: 85, height: 70).background(Theme.background.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.22)))
            .accessibilityLabel("Weather overview. Green zones strengthen the tornado.")
    }
    private var pauseOverlay: some View {
        landscapeOverlay {
            HStack(alignment: .center, spacing: 22) {
                VStack(spacing: 9) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.mint)
                    Text("Paused")
                        .font(.title2.bold())
                    Text("Your coins are saved. Your run resumes right here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Button("Resume") {
                        session.setPaused(false)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("resumeButton")
                    Button("Leave run") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text("Leaving resets this run's objectives, but keeps earned coins.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func resultOverlay(_ summary: RunSummary) -> some View {
        landscapeOverlay {
            HStack(alignment: .center, spacing: 22) {
                VStack(spacing: 9) {
                    Image(systemName: summary.won ? "checkmark.seal.fill" : "cloud.fog.fill")
                        .font(.system(size: 35))
                        .foregroundStyle(summary.won ? Theme.mint : Theme.muted)
                    Text(summary.won ? "Outbreak complete" : "Tornado dissipated")
                        .font(.title3.bold())
                        .accessibilityIdentifier("resultTitle")
                        .multilineTextAlignment(.center)
                    Text(summary.won
                        ? "\(session.level.name) · all objectives complete"
                        : "Find warm, moist air to keep your energy up.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        stat("EF\(summary.peakEF)", "PEAK")
                        stat("\(summary.destroyed)", "DESTROYED")
                        stat("\(summary.seconds)s", "SURVIVED")
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 9) {
                    Text("+\(summary.coins) TC earned")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                    if summary.won {
                        Text("Includes \(summary.completion) TC completion reward · \(summary.firstCompletion ? "First clear 100%" : "Replay 25%")")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    Button("Choose level") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Play again") { replay() }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("Progress saved automatically")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.headline, design: .rounded).bold())
            Text(caption)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.muted)
        }
    }

    private func landscapeOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.75).ignoresSafeArea()
                ScrollView {
                    content()
                        .padding(18)
                        .frame(maxWidth: 700)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 22))
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

}

private struct Joystick: View {
    let move: (Point) -> Void
    @State private var offset = CGSize.zero
    var body: some View {
        ZStack {
            Circle().fill(Theme.background.opacity(0.8))
            Circle().stroke(.white.opacity(0.16), lineWidth: 1)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 36, weight: .ultraLight)).foregroundStyle(.white.opacity(0.1))
            Circle().fill(Theme.mint.opacity(0.22)).frame(width: 44, height: 44)
                .overlay(Circle().stroke(Theme.mint.opacity(0.6), lineWidth: 1.5))
                .offset(offset)
        }.frame(width: 108, height: 108).contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - 54
                        let dy = value.location.y - 54
                        let distance = hypot(dx, dy)
                        let maximum: CGFloat = 35
                        let scale = distance > maximum ? maximum / distance : 1
                        offset = CGSize(width: dx * scale, height: dy * scale)
                        move(Point(Double(offset.width / maximum), -Double(offset.height / maximum)))
                    }
                    .onEnded { _ in
                        offset = .zero
                        move(Point(0, 0))
                    }
            )
            .onDisappear { move(Point(0, 0)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Steering thumbstick. Drag to move.")
            .accessibilityIdentifier("joystick")
    }
}

