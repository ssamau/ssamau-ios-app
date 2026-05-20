import SwiftUI

/// First-login activation — spec §4 (both token + PIN paths).
///
/// Two entry points:
///   1. Manual: user opens the screen from LoginView's "Have an invite?"
///      link, defaults to PIN mode, can toggle to token mode.
///   2. Universal Link: `ssamau.com/signup.html?token=<hex>` opens the
///      app here with `prefilledToken` set → starts in token mode with
///      the field populated. (Requires AASA + Associated Domains, both
///      pending paid-cert distribution.)
struct SignupCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SignupCompleteViewModel
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case token, nid, pin, password, confirm
    }

    init(prefilledToken: String? = nil, initialMode: SignupCompleteViewModel.Mode = .pin) {
        _vm = StateObject(wrappedValue:
            SignupCompleteViewModel(initialMode: initialMode, prefilledToken: prefilledToken)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                // Force the entire form into LTR layout. Every input on
                // this screen carries LTR-only data (hex token, digit
                // NID/PIN, ASCII passwords). Without this, SwiftUI's
                // RTL bug eats the first keystroke AND can sneak RTL
                // marks into the submitted string — which is why the
                // PIN was being rejected with "invalid credentials".
                card
                    .environment(\.layoutDirection, .leftToRight)
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
        .onReceive(vm.$didActivate) { activated in
            if activated {
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            Text(LocalizedStringKey("su.welcome"))
                .font(.ssH1)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            GoldRule(width: 40)
            Text(LocalizedStringKey(
                vm.mode == .token ? "su.token_mode_welcome" : "su.pin_mode_welcome"
            ))
            .font(.ssCaption)
            .foregroundStyle(Color.ssGrey)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 16) {
            switch vm.mode {
            case .token: tokenField
            case .pin:   pinFields
            }

            passwordField
            confirmPasswordField

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
            modeSwitch
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

    // MARK: - Fields

    private var tokenField: some View {
        labeled(LocalizedStringKey("login.identifier_label")) {
            TextField("token", text: $vm.token)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.next)
                .focused($focused, equals: .token)
                .onSubmit { focused = .password }
        }
    }

    private var pinFields: some View {
        VStack(spacing: 12) {
            labeled(LocalizedStringKey("su.nid_label")) {
                TextField(LocalizedStringKey("su.nid_placeholder"), text: $vm.nationalId)
                    .font(.ssBody)
                    .foregroundStyle(Color.ssCharcoal)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .focused($focused, equals: .nid)
                    .onChange(of: vm.nationalId) { newValue in
                        vm.nationalId = String(newValue.filter(\.isNumber).prefix(10))
                    }
            }
            labeled(LocalizedStringKey("su.pin_label")) {
                TextField(LocalizedStringKey("su.pin_placeholder"), text: $vm.pin)
                    .font(.ssBody)
                    .foregroundStyle(Color.ssCharcoal)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .focused($focused, equals: .pin)
                    .onChange(of: vm.pin) { newValue in
                        vm.pin = String(newValue.filter(\.isNumber).prefix(6))
                    }
            }
        }
    }

    private var passwordField: some View {
        labeled(LocalizedStringKey("su.password_label")) {
            SecureField(LocalizedStringKey("su.password_placeholder"), text: $vm.password)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.next)
                .focused($focused, equals: .password)
                .onSubmit { focused = .confirm }
        }
    }

    private var confirmPasswordField: some View {
        labeled(LocalizedStringKey("su.confirm_label")) {
            SecureField(LocalizedStringKey("su.confirm_placeholder"), text: $vm.confirmPassword)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.go)
                .focused($focused, equals: .confirm)
                .onSubmit { Task { await vm.submit() } }
        }
    }

    private var submitButton: some View {
        Button {
            focused = nil
            Task { await vm.submit() }
        } label: {
            ZStack {
                Text(LocalizedStringKey("su.submit"))
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

    private var modeSwitch: some View {
        Button {
            focused = nil
            vm.switchMode()
        } label: {
            Text(LocalizedStringKey(
                vm.mode == .token
                ? "su.mode_switch_to_pin"
                : "su.mode_switch_to_link"
            ))
            .font(.ssCaption)
            .foregroundStyle(Color.ssGreen)
            .multilineTextAlignment(.center)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backLink: some View {
        Button { dismiss() } label: {
            Text(LocalizedStringKey("su.back_to_login"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGreen)
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building blocks

    private func labeled<V: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            content()
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
}

#Preview {
    NavigationStack { SignupCompleteView() }
}
