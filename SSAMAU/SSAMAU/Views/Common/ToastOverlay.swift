import SwiftUI
import UIKit

/// Reusable bottom toast overlay. Apply on every screen AND every modal
/// sheet that can trigger the same toast — when a sheet is open over a
/// parent, both views share the binding and both render the toast, so
/// wherever the user is looking, the message lands on top of their
/// current context.
///
/// Animation tries to feel iOS-native: spring scale-in from below with
/// opacity, light haptic on appear, gentle ease-out on dismiss.
struct ToastOverlay: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ZStack {
                    if let toast {
                        toastCapsule(toast)
                            .id(toast.id)
                            .transition(
                                .asymmetric(
                                    insertion:
                                        .scale(scale: 0.9, anchor: .bottom)
                                        .combined(with: .opacity)
                                        .combined(with: .move(edge: .bottom)),
                                    removal:
                                        .opacity
                                        .combined(with: .scale(scale: 0.96, anchor: .bottom))
                                )
                            )
                            .task(id: toast.id) {
                                // Fire haptic on appear; replays for each new toast.
                                let gen = UINotificationFeedbackGenerator()
                                gen.prepare()
                                gen.notificationOccurred(toast.kind.haptic)
                                // Auto-dismiss after 3.2s, animated.
                                try? await Task.sleep(nanoseconds: 3_200_000_000)
                                if self.toast?.id == toast.id {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        self.toast = nil
                                    }
                                }
                            }
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: toast?.id)
            }
    }

    private func toastCapsule(_ toast: Toast) -> some View {
        HStack(spacing: 10) {
            Image(systemName: toast.kind.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(toast.message)
                .font(.ssCaption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toast.kind.background, in: Capsule())
        .shadow(color: Color.ssCharcoal.opacity(0.28), radius: 10, y: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: 480)
        // Tap-to-dismiss for impatient users.
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) {
                self.toast = nil
            }
        }
    }
}

extension View {
    /// Shows a transient bottom toast when `toast` is non-nil. Auto-clears
    /// after ~3 seconds (animated). Apply on both a parent screen and any
    /// sheet that triggers an action so the user sees the toast wherever
    /// they happen to be looking.
    func ssToast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastOverlay(toast: toast))
    }
}
