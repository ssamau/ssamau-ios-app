import Foundation

/// Centralised access to the bundle's marketing + build version. The
/// values come from CFBundleShortVersionString + CFBundleVersion, which
/// are set in project.pbxproj (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`).
/// Build number is bumped by `scripts/bump-build.sh` on every release.
enum AppInfo {
    /// Marketing version (e.g. "0.1"). Bumped manually when a release
    /// changes user-facing behaviour meaningfully.
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Build number (e.g. "64"). Bumped on every commit via the
    /// `scripts/bump-build.sh` helper (driven by git rev-list --count).
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Is this version still in the beta phase? Currently driven by a
    /// marketing-version threshold: anything below 1.0 is beta. Once
    /// we ship 1.0 to the App Store, flip the threshold or remove.
    static var isBeta: Bool {
        let parts = marketingVersion.split(separator: ".").compactMap { Int($0) }
        return (parts.first ?? 0) < 1
    }

    /// "Beta 0.1 (64)" / "1.0 (120)" depending on the phase. The build
    /// number is bracketed per Apple's HIG convention.
    static var displayVersion: String {
        let prefix = isBeta ? "Beta " : ""
        return "\(prefix)\(marketingVersion) (\(buildNumber))"
    }

    /// Compact "0.1+64" form for the X-App-Version header (server logs).
    /// Doesn't include the "Beta" prefix — the server cares about the
    /// shipped version, not the marketing label.
    static var serverVersion: String {
        "\(marketingVersion)+\(buildNumber)"
    }
}

import SwiftUI

/// Small, low-contrast version stamp meant to live at the bottom of
/// pre-auth screens (Login, Reset password, Signup) and any other
/// screen the user might land on before they pick their portal.
/// Tappable to copy the version to clipboard — useful when they
/// screenshot the screen for a support ticket.
struct VersionFooter: View {
    var body: some View {
        Button {
            UIPasteboard.general.string = AppInfo.displayVersion
        } label: {
            Text(AppInfo.displayVersion)
                .font(.ssTiny)
                .foregroundStyle(Color.ssGrey)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("App version \(AppInfo.displayVersion)"))
    }
}
