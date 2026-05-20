import SwiftUI
import UIKit

/// Transient toast message. ViewModels expose `@Published var toast: Toast?`
/// and views attach `.ssToast($vm.toast)`.
struct Toast: Equatable, Identifiable {
    /// UUID per-toast so successive toasts with the same text restart
    /// the auto-dismiss timer + replay the animation/haptic.
    let id = UUID()
    let message: String
    let kind: Kind

    enum Kind: Equatable {
        case success
        case error
        case info

        var systemImage: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error:   return "exclamationmark.triangle.fill"
            case .info:    return "info.circle.fill"
            }
        }

        var background: Color {
            switch self {
            case .success: return .ssGreen
            case .error:   return .red
            case .info:    return .ssGold
            }
        }

        var haptic: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: return .success
            case .error:   return .error
            case .info:    return .warning
            }
        }
    }

    static func success(_ message: String) -> Toast {
        Toast(message: message, kind: .success)
    }
    static func error(_ message: String) -> Toast {
        Toast(message: message, kind: .error)
    }
    static func info(_ message: String) -> Toast {
        Toast(message: message, kind: .info)
    }
}
