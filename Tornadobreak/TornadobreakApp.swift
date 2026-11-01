import SwiftUI

@main
struct TornadobreakApp: App {
    @StateObject private var store = ProgressStore()
    var body: some Scene {
        WindowGroup {
            MenuView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
    }
}
