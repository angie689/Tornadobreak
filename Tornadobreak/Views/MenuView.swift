import SwiftUI
import TornadoCore

struct MenuView: View {
    @EnvironmentObject private var store: ProgressStore
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.mint.opacity(0.12), .clear], center: .topTrailing,
                    startRadius: 10, endRadius: 490
                ).ignoresSafeArea()
                GeometryReader { geometry in
                    ScrollView {
                        HStack(alignment: .center, spacing: 32) {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("TORNADOBREAK")
                                        .font(.caption.weight(.heavy)).tracking(3)
                                        .foregroundStyle(Theme.muted)
                                    Spacer()
                                }
                                ZStack {
                                    ForEach(0..<4) { index in
                                        Circle().trim(from: 0.08, to: 0.86)
                                            .stroke(
                                                Theme.mint.opacity(0.12 + Double(index) * 0.07),
                                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                            )
                                            .frame(
                                                width: CGFloat(80 + index * 30),
                                                height: CGFloat(80 + index * 30)
                                            )
                                            .rotationEffect(.degrees(Double(index) * 65 - 20))
                                    }
                                    Image(systemName: "hurricane")
                                        .font(.system(size: 58, weight: .light))
                                        .foregroundStyle(Theme.mint)
                                }
                                .frame(maxWidth: .infinity, minHeight: 190)
                                .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 11) {
                                HStack {
                                    Spacer()
                                    CoinPill(amount: store.progress.coins)
                                }
                                Text("Small funnel. Big outbreak.")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .tracking(-1).minimumScaleFactor(0.8)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Chase warm air. Build your strength. Leave a path through three real cities.")
                                    .font(.footnote).foregroundStyle(Theme.muted)
                                NavigationLink {
                                    LevelSelectView()
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .accessibilityIdentifier("playButton")
                                NavigationLink {
                                    UpgradesView()
                                } label: {
                                    Label("Upgrades", systemImage: "slider.horizontal.3")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                Text("V1.0  ·  SINGLE PLAYER  ·  SAVED ON THIS DEVICE")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 26).padding(.vertical, 14)
                        .frame(minHeight: geometry.size.height)
                    }.scrollIndicators(.hidden)
                }
            }
        }
    }
}

struct LevelSelectView: View {
    @EnvironmentObject private var store: ProgressStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Choose your outbreak").font(.title2.bold())
                    Spacer()
                }
                Text("Three cities. Three objectives each. Upgrades carry into every run.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                ForEach(Level.all) { level in
                    NavigationLink {
                        GameScreen(level: level, store: store)
                    } label: {
                        levelCard(level)
                    }.buttonStyle(.plain).accessibilityIdentifier("level-\(level.id)")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("How to play", systemImage: "hand.draw.fill").font(.headline)
                    Text(
                        "Drag the thumbstick to steer. Green zones are warm and moist: stay there to grow. Blue zones weaken you. Pass close to objects to lift them."
                    )
                    Text(
                        "Finish all three objectives in one run. At zero energy, you have 8 seconds to reach better air. Pause whenever you need."
                    )
                    Text(
                        "Maps show real geography. Weather and object placements are designed for the game; they are not live data."
                    )
                }.font(.footnote).foregroundStyle(Theme.muted).gamePanel()
                Text("Coins and earned bonuses save immediately. An unfinished run restarts when you leave it.")
                    .font(.footnote).foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }.padding(20)
        }
        .background(Theme.background).navigationTitle("Play").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CoinPill(amount: store.progress.coins) } }
    }
    private func levelCard(_ level: Level) -> some View {
        let done = store.progress.completedLevels.contains(level.id)
        let color: Color = level.id == "moore" ? Theme.mint : level.id == "dallas" ? .orange : .purple
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.difficulty.uppercased()).font(.caption2.bold()).tracking(2).foregroundStyle(color)
                    Text(level.name).font(.system(.title, design: .rounded).bold())
                    Text(level.state).font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: done ? "checkmark.circle.fill" : "arrow.up.right")
                    .font(.title3).foregroundStyle(color).padding(10)
                    .background(color.opacity(0.1), in: Circle())
            }
            HStack {
                Text("EF\(level.quests[0].target) · \(level.quests[1].target) objects · \(level.quests[2].target)s")
                Spacer(minLength: 4)
                Text("+\(done ? level.reward / 4 : level.reward) TC").foregroundStyle(.yellow)
            }.font(.caption.weight(.semibold))
            Text(done ? "Completed · replay reward 25%" : "First completion reward 100% · +20 TC per new quest")
                .font(.caption2).foregroundStyle(Theme.muted)
        }.gamePanel()
    }
}

struct UpgradesView: View {
    @EnvironmentObject private var store: ProgressStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A stronger next run.").font(.title2.bold())
                Text("Permanent improvements, bought with Tornado Coins. Three ranks each.")
                    .foregroundStyle(Theme.muted).font(.subheadline)
                ForEach(Upgrade.allCases) { upgrade in
                    upgradeCard(upgrade)
                }
            }.padding(20)
        }.background(Theme.background).navigationTitle("Upgrades").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CoinPill(amount: store.progress.coins) } }
    }
    private func upgradeCard(_ upgrade: Upgrade) -> some View {
        let rank = store.progress.rank(upgrade)
        let cost = Upgrade.cost(rank: rank)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(upgrade.title).font(.title3.bold())
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<Upgrade.maxRank, id: \.self) { index in
                        Capsule().fill(index < rank ? Theme.mint : Color.white.opacity(0.12)).frame(
                            width: 24, height: 6)
                    }
                }.accessibilityLabel("Rank \(rank) of 3")
            }
            Text(upgrade.detail).foregroundStyle(Theme.muted).font(.subheadline)
            Button {
                store.purchase(upgrade)
            } label: {
                Text(rank == Upgrade.maxRank ? "Fully upgraded" : "Upgrade · \(cost) TC")
            }.buttonStyle(SecondaryButtonStyle())
                .disabled(rank == Upgrade.maxRank || store.progress.coins < cost)
                .opacity(rank == Upgrade.maxRank || store.progress.coins < cost ? 0.45 : 1)
                .accessibilityIdentifier("upgrade-\(upgrade.rawValue)")
        }.gamePanel()
    }
}
