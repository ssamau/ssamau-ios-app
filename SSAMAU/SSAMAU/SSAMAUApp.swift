import SwiftUI

@main
struct SSAMAUApp: App {
    @StateObject private var session = SessionStore.shared

    init() {
        #if DEBUG
        print("📍 Bundle.main.localizations:          \(Bundle.main.localizations)")
        print("📍 Bundle.main.preferredLocalizations: \(Bundle.main.preferredLocalizations)")
        print("📍 Locale.current.identifier:          \(Locale.current.identifier)")
        print("📍 NSLocalizedString('lang.toggle_title') → \"\(NSLocalizedString("lang.toggle_title", comment: ""))\"")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
