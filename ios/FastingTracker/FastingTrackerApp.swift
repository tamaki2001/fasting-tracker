import SwiftUI

@main
struct FastingTrackerApp: App {
    @State private var store = FastingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
