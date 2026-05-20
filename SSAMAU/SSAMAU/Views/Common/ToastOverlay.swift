import SwiftUI
import UIKit

/// Reusable bottom toast overlay. Apply on every screen AND every modal
/// sheet that can trigger the same toast — when a sheet is open over a
/// parent, both views share the binding and both render the toast, so
/// wherever the user is looking, the message lands on top of their
/// current context.
///
/// Animation is iOS-native: spring scale-in from below with opacity on
/// insert, gentle ease-out on dismiss, light haptic on appear. The
/// mirror-into-@State pattern guarantees the insert animates even when
/// the source binding is updated outside a withAnimation block (which
/// is the common case from ViewModels).
struct ToastOverlay: ViewModifier {
    @Binding var toast: Toast?
    @State private var displayed: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let displayed {
                    toastCapsule(displayed)
                        .transition(
                            .asymmetric(
                                insertion:
                                    .scale(scale: 0.85, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .move(edge: .bottom)),
                                removal:
                                    .opacity
                                    .combined(with: .scale(scale: 0.96, anchor: .bottom))
                            )
                        )
                        .task(id: displayed.id) {
                            // Haptic on appear; replays per new toast.
                            let gen = UINotificationFeedbackGenerator()
                            gen.prepare()
                            gen.notificationOccurred(displayed.kind.haptic)
                            // Auto-dismiss after 3.2s, animated.
                            try? await Task.sleep(nanoseconds: 3_200_000_000)
                            guard self.displayed?.id == displayed.id else { return }
                            withAnimation(.easeInOut(duration: 0.28)) {
                                self.displayed = nil
                                self.toast = nil
                            }
                        }
                }
            }
            // Mirror external binding → local @State inside withAnimation
            // so the insert always gets a transition context.
            .onChange(of: toast) { newValue in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    displayed = newValue
                }
            }
            .onAppear {
                // Sync any pre-existing toast value on first appear.
                if displayed == nil, let initial = toast {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        displayed = initial
                    }
                }
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
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) {
                self.displayed = nil
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
