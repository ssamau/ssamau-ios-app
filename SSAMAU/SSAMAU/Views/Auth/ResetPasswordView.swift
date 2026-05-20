import SwiftUI

/// Password-reset request screen — spec §4.
/// Submits to `auth.requestPasswordReset`; server sends a Supabase Auth
/// recovery email to the identifier's canonical email address.
/// Server always returns `{ sent: true }` (anti-enumeration), so the
/// success message is generic.
struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ResetPasswordViewModel()
    @FocusState private var identifierFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                card
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color.ssCream.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            Text(LocalizedStringKey("reset.title"))
                .font(.ssH1)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            GoldRule(width: 40)
            Text(LocalizedStringKey("reset.intro"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 16) {
            identifierField

            if let success = vm.successMessage {
                Text(success)
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = vm.errorMessage {
                Text(error)
                    .font(.ssCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            submitButton

            backLink
        }
        .padding(22)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var identifierField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("reset.identifier_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            TextField(
                LocalizedStringKey("reset.identifier_placeholder"),
                text: $vm.identifier
            )
            .font(.ssBody)
            .foregroundStyle(Color.ssCharcoal)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.emailAddress)
            .submitLabel(.send)
            .focused($identifierFocused)
            .onSubmit { Task { await vm.submit() } }
            // LTR — email / NID. Works around SwiftUI RTL cursor bug.
            .environment(\.layoutDirection, .leftToRight)
            .multilineTextAlignment(.leading)
            .padding(12)
            .background(Color.ssCream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ssLight, lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        Button {
            identifierFocused = false
            Task { await vm.submit() }
        } label: {
            ZStack {
                Text(LocalizedStringKey("reset.submit"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .opacity(vm.isLoading ? 0 : 1)
                if vm.isLoading {
                    ProgressView().tint(Color.ssCream)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(vm.canSubmit ? Color.ssGreen : Color.ssGrey)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!vm.canSubmit)
    }

    private var backLink: some View {
        Button {
            dismiss()
        } label: {
            Text(LocalizedStringKey("reset.back"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGreen)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

#Preview {
    NavigationStack { ResetPasswordView() }
}
