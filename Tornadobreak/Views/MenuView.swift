import SwiftUI
import TornadoCore

struct MenuView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    HStack(alignment: .center, spacing: 22) {
                        heroPanel
                            .frame(maxWidth: .infinity)
                        actionsPanel
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .background {
                    ZStack {
                        Theme.background
                        RadialGradient(
                            colors: [Theme.mint.opacity(0.12), .clear],
                            center: .topTrailing, startRadius: 10, endRadius: 490)
                    }
                    .ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var heroPanel: some View {
        VStack(spacing: 10) {
            Text("TORNADOBREAK")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .trim(from: 0.08, to: 0.86)
                        .stroke(
                            Theme.mint.opacity(0.12 + Double(index) * 0.07),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(
                            width: CGFloat(64 + index * 25),
                            height: CGFloat(64 + index * 25))
                        .rotationEffect(.degrees(Double(index) * 65 - 20))
                }
                Image(systemName: "hurricane")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.mint)
            }
            .frame(height: 154)
            .accessibilityHidden(true)
            Text("Small funnel. Big outbreak.")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var actionsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                CoinPill(amount: store.progress.coins)
            }
            Text("Chase warm air, grow stronger, and tear through eight real cities.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
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
            Text("V1.1 · SINGLE PLAYER · LOCAL SAVES")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: 360)
    }
}

struct LevelSelectView: View {
    @EnvironmentObject private var store: ProgressStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Choose your outbreak").font(.headline)
                    Spacer(minLength: 5)
                    Text("Eight cities · changing weather")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Level.all) { level in
                        NavigationLink {
                            GameScreen(level: level, store: store)
                        } label: {
                            levelCard(level)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("level-\(level.id)")
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Label("How to play", systemImage: "hand.draw.fill")
                        .font(.caption.bold())
                    Text("Drag the joystick to steer. Follow moving green weather in every city after Moore; blue weather weakens you. Overlapping green bubbles make super hot air, overlapping blue bubbles make super cold air, and a green-blue overlap is mixed. Heavy debris costs energy, and in the toughest cities even mixed air drains you.")
                    Text("Finish all three quests in one run. Keep moving to grow; coins and upgrades save automatically.")
                }
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
        .navigationTitle("Play")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CoinPill(amount: store.progress.coins)
            }
        }
    }

    private func levelCard(_ level: Level) -> some View {
        let done = store.progress.completedLevels.contains(level.id)
        let palette: [Color] = [Theme.mint, .orange, .purple, .pink, .red, .cyan, .white, .yellow]
        let tier = Level.all.firstIndex(where: { $0.id == level.id }) ?? 0
        let color = palette[min(tier, palette.count - 1)]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(level.difficulty.uppercased())
                    .font(.caption2.bold())
                    .tracking(1)
                    .foregroundStyle(color)
                Spacer(minLength: 2)
                Image(systemName: done ? "checkmark.circle.fill" : "arrow.up.right")
                    .foregroundStyle(color)
            }
            Text(level.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(level.state)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 4)
            Text("EF\(level.quests[0].target) · \(level.quests[1].target) objects · \(level.quests[2].target)s")
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Text(done ? "Replay · 25%" : "First clear · 100%")
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                Text("+\(done ? level.reward / 4 : level.reward) TC")
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
            }
            .font(.caption2.bold())
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct UpgradesView: View {
    @EnvironmentObject private var store: ProgressStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("A stronger next run.").font(.headline)
                    Spacer(minLength: 4)
                    Text("Permanent upgrades · five ranks each")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Upgrade.allCases) { upgrade in
                        upgradeCard(upgrade)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
        .navigationTitle("Upgrades")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CoinPill(amount: store.progress.coins)
            }
        }
    }

    private func upgradeCard(_ upgrade: Upgrade) -> some View {
        let rank = store.progress.rank(upgrade)
        let cost = Upgrade.cost(rank: rank)
        return VStack(alignment: .leading, spacing: 9) {
            Text(upgrade.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 5) {
                ForEach(0..<Upgrade.maxRank, id: \.self) { index in
                    Capsule()
                        .fill(index < rank ? Theme.mint : Color.white.opacity(0.12))
                        .frame(width: 24, height: 6)
                }
                Spacer()
                Text("\(rank)/\(Upgrade.maxRank)")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("Rank \(rank) of \(Upgrade.maxRank)")
            Text(upgrade.detail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 39, alignment: .topLeading)
            Button {
                store.purchase(upgrade)
            } label: {
                Text(rank == Upgrade.maxRank ? "Fully upgraded" : "Upgrade · \(cost) TC")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(rank == Upgrade.maxRank || store.progress.coins < cost)
            .opacity(rank == Upgrade.maxRank || store.progress.coins < cost ? 0.45 : 1)
            .accessibilityIdentifier("upgrade-\(upgrade.rawValue)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
    }
}
