import SwiftUI

@main
struct TenonakaApp: App {
    @StateObject private var store = LetterStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
