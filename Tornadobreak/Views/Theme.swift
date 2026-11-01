import SwiftUI

 enum Theme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.08)
    static let panel = Color(red: 0.08, green: 0.11, blue: 0.15)
    static let mint = Color(red: 0.42, green: 0.94, blue: 0.77)
    static let muted = Color(red: 0.61, green: 0.68, blue: 0.75)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(Theme.background)
            .background(Theme.mint.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct CoinPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.hexagongrid.fill").font(.caption)
            Text("\(amount) TC").font(.system(.subheadline, design: .rounded).bold()).monospacedDigit()
        }
        .foregroundStyle(.yellow).padding(.horizontal, 12).padding(.vertical, 9)
        .background(.yellow.opacity(0.09), in: Capsule())
        .accessibilityLabel("\(amount) Tornado Coins")
    }
}
extension View {
    func gamePanel() -> some View {
        self.padding(18).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
    }
}
