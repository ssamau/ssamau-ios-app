import SwiftUI

@main
struct SSAMAUApp: App {
    @StateObject private var session = SessionStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
