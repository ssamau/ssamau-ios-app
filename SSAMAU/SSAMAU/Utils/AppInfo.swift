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
