import SwiftUI

@main
struct TenonakaApp: App {
    @StateObject private var store = LetterStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                // 波の音は画面ごとに切り替えない。海がこのアプリの世界そのものなので、
                // 前面にいるあいだ鳴らし続ける。消音スイッチで止められる(.ambient)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: SeaSound.shared.start()
                    default: SeaSound.shared.stop()
                    }
                }
        }
    }
}
