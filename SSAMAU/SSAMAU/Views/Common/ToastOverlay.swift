import SwiftUI

/// Reusable bottom toast overlay backed by a binding. Apply on every
/// screen AND every modal sheet that can trigger the same toast — when
/// a sheet is open over a parent, both views share the binding and both
/// render the toast, so wherever the user is looking at the time, the
/// message lands on top of their current context. (Parent-only overlays
/// get hidden under .sheet presentations.)
struct ToastOverlay: ViewModifier {
    @Binding var message: String?
    var isError: Bool = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = message {
                Text(msg)
                    .font(.ssCaption)
                    .foregroundStyle(isError ? .white : Color.ssCream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(isError ? Color.red : Color.ssGreen)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .shadow(color: Color.ssCharcoal.opacity(0.25), radius: 8, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: msg) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if message == msg { message = nil }
                    }
            }
        }
    }
}

extension View {
    /// Shows a transient green toast at the bottom when `message` is non-nil.
    /// Auto-clears after 3s. Safe to apply on both a parent screen and any
    /// sheet it presents — both see the same binding so the toast lands
    /// wherever the user is looking.
    func ssToast(_ message: Binding<String?>) -> some View {
        modifier(ToastOverlay(message: message, isError: false))
    }
}
