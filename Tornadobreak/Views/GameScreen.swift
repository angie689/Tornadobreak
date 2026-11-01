import SwiftUI
import SpriteKit
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
    private var hud: some View {
        VStack(spacing: 10) {
            HStack {
                Button { session.setPaused(true) } label: {
                    Image(systemName: "pause.fill").font(.headline).frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                }.accessibilityLabel("Pause").accessibilityIdentifier("pauseButton")
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.level.name).font(.headline)
                    Text(session.level.difficulty.uppercased()).font(.system(size: 9, weight: .bold))
                        .tracking(2).foregroundStyle(Theme.muted)
                }
                Spacer()
                CoinPill(amount: session.coins)
            }
            HStack(spacing: 12) {
                Text("EF\(session.simulation.ef)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.mint).frame(width: 74)
                    .accessibilityIdentifier("strengthLabel")
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(session.simulation.wind) mph").font(.headline).monospacedDigit()
                        Spacer()
                        Text("\(Int(session.simulation.elapsed))s").font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    ProgressView(value: session.simulation.energy, total: 100).tint(Theme.mint)
                        .accessibilityLabel("Energy \(Int(session.simulation.energy)) percent")
                    HStack(spacing: 5) {
                        Circle().fill(weatherColor).frame(width: 6, height: 6)
                        Text("\(session.simulation.weather.rawValue) · \(session.simulation.weather.hint)")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(weatherColor)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            Divider().overlay(.white.opacity(0.1))
            VStack(spacing: 5) {
                ForEach(session.level.quests) { quest in
                    let done = session.simulation.achieved.contains(quest.kind)
                    HStack(spacing: 7) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Theme.mint : Theme.muted)
                        Text(quest.title)
                        Spacer()
                        Text("\(min(quest.target, session.simulation.value(for: quest)))/\(quest.target)")
                            .foregroundStyle(Theme.muted).monospacedDigit()
                    }.font(.system(size: 11, weight: .medium))
                }
            }
        }.padding(14)
            .background(Theme.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 12).padding(.top, 5)
    }
    private var weatherColor: Color {
        switch session.simulation.weather { case .warm: return Theme.mint; case .mixed: return .yellow; case .dry: return .cyan }
    }
    private var controls: some View {
        VStack(spacing: 8) {
            if session.simulation.energy < 10 && session.simulation.weather == .dry {
                Text("LOW ENERGY · Move to green air!").font(.caption.bold()).foregroundStyle(.orange)
                    .padding(10).background(Theme.background.opacity(0.9), in: Capsule())
            }
            HStack(alignment: .bottom) {
                Joystick { session.scene.setDirection($0) }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    miniMap
                    Text("N ↑").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                }.padding(.bottom, 12)
            }.padding(.horizontal, 22)
            Text(session.toast).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.mint)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.background.opacity(0.8), in: Capsule())
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(session.level.name), \(session.level.state)")
                    Text(session.mapStatus)
                }
                Spacer(minLength: 4)
                Text("Maps © Apple\nGame objects are illustrative")
                    .multilineTextAlignment(.trailing)
            }.font(.system(size: 8)).foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 14).padding(.vertical, 5).background(Theme.background.opacity(0.8))
        }
    }
    private var miniMap: some View {
        Canvas { context, size in
            let scaleX = size.width / Level.worldSize.x, scaleY = size.height / Level.worldSize.y
            for zone in session.level.zones {
                let rect = CGRect(x: (zone.center.x - zone.radius) * scaleX,
                                  y: (Level.worldSize.y - zone.center.y - zone.radius) * scaleY,
                                  width: zone.radius * 2 * scaleX, height: zone.radius * 2 * scaleY)
                context.fill(Path(ellipseIn: rect), with: .color((zone.favorable ? Theme.mint : .blue).opacity(0.24)))
            }
            let position = session.simulation.position
            let dot = CGRect(x: position.x * scaleX - 3, y: (Level.worldSize.y - position.y) * scaleY - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dot), with: .color(.white))
        }.frame(width: 80, height: 110).background(Theme.background.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.22)))
            .accessibilityLabel("Weather overview. Green zones strengthen the tornado.")
    }
    private var pauseOverlay: some View {
        overlayContainer {
            Image(systemName: "pause.circle").font(.system(size: 48)).foregroundStyle(Theme.mint)
            Text("Take a breather.").font(.title.bold())
            Text("Your coins are saved. Your run will resume right here.")
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Resume") { session.setPaused(false) }.buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("resumeButton")
            Button("Leave run") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            Text("Leaving resets these objectives, but keeps earned coins and bonuses.")
                .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
    }
    private func resultOverlay(_ summary: RunSummary) -> some View {
        overlayContainer {
            Image(systemName: summary.won ? "checkmark.seal.fill" : "cloud.fog.fill")
                .font(.system(size: 50)).foregroundStyle(summary.won ? Theme.mint : Theme.muted)
            Text(summary.won ? "Outbreak complete" : "Tornado dissipated")
                .font(.title2.bold()).accessibilityIdentifier("resultTitle")
            Text(summary.won ? "\(session.level.name) · all objectives complete" : "Find warm, moist air to keep your energy up.")
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            HStack(spacing: 20) {
                stat("EF\(summary.peakEF)", "PEAK")
                stat("\(summary.destroyed)", "DESTROYED")
                stat("\(summary.seconds)s", "SURVIVED")
            }.padding(.vertical, 10)
            Text("+\(summary.coins) TC earned").font(.title2.bold()).foregroundStyle(.yellow)
            if summary.won {
                Text("Includes \(summary.completion) TC completion reward\n\(summary.firstCompletion ? "First completion · 100%" : "Replay · 25%")")
                    .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            Button("Choose level") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            Button("Play again") { replay() }.buttonStyle(SecondaryButtonStyle())
            Text("Progress saved automatically").font(.caption).foregroundStyle(Theme.muted)
        }
    }
    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(.title3, design: .rounded).bold())
            Text(caption).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.muted)
        }
    }
    private func overlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 17, content: content).padding(26)
                    .frame(maxWidth: 400).background(Theme.panel, in: RoundedRectangle(cornerRadius: 28))
                    .padding(20).frame(maxWidth: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.system(size: 48, weight: .ultraLight)).foregroundStyle(.white.opacity(0.1))
            Circle().fill(Theme.mint.opacity(0.22)).frame(width: 54, height: 54)
                .overlay(Circle().stroke(Theme.mint.opacity(0.6), lineWidth: 1.5))
                .offset(offset)
        }.frame(width: 132, height: 132).contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.location.x - 66, dy = value.location.y - 66
                    let distance = hypot(dx, dy), maximum: CGFloat = 45
                    let scale = distance > maximum ? maximum / distance : 1
                    offset = CGSize(width: dx * scale, height: dy * scale)
                    move(Point(Double(offset.width / maximum), -Double(offset.height / maximum)))
                }
                .onEnded { _ in offset = .zero; move(Point(0, 0)) })
            .onDisappear { move(Point(0, 0)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Steering thumbstick. Drag to move.")
            .accessibilityIdentifier("joystick")
    }
}

