import SwiftUI

/// Sign-in screen — spec §8.1.
struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case identifier, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                card
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color("Background").ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        // Pad ScrollView below the focused field so the submit button
        // stays visible when the keyboard rises. SwiftUI auto-avoidance
        // doesn't cover all layouts cleanly.
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                Color.clear.frame(height: 8)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text(LocalizedStringKey("brand.ssam_full"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color("Ink"))
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey("login.welcome"))
                .font(.callout)
                .foregroundStyle(Color("InkMuted"))
                .multilineTextAlignment(.center)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            identifierField
            passwordField

            if let error = vm.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            submitButton

            // Phase 2 — wire to ResetPasswordView via NavigationLink.
            Button {} label: {
                Text(LocalizedStringKey("login.forgot"))
                    .font(.footnote)
                    .foregroundStyle(Color("BrandGreen"))
            }
            .disabled(true)
            .opacity(0.5)

            Button {
                openAppSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text(LocalizedStringKey("lang.toggle_title"))
                }
                .font(.footnote)
                .foregroundStyle(Color("BrandGreen"))
            }
        }
        .padding(20)
        .background(Color("BackgroundSoft"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("Line"), lineWidth: 1)
        )
    }

    private var identifierField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("login.identifier_label"))
                .font(.footnote)
                .foregroundStyle(Color("InkMuted"))
            TextField(
                LocalizedStringKey("login.identifier_placeholder"),
                text: $vm.identifier
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.emailAddress)
            .submitLabel(.next)
            .focused($focusedField, equals: .identifier)
            .onSubmit { focusedField = .password }
            .textFieldStyle(BorderedTextFieldStyle())
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("login.password_label"))
                .font(.footnote)
                .foregroundStyle(Color("InkMuted"))
            HStack(spacing: 8) {
                Group {
                    if vm.isPasswordVisible {
                        TextField(
                            LocalizedStringKey("login.password_placeholder"),
                            text: $vm.password
                        )
                    } else {
                        SecureField(
                            LocalizedStringKey("login.password_placeholder"),
                            text: $vm.password
                        )
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit { Task { await vm.signIn() } }

                Button {
                    vm.isPasswordVisible.toggle()
                } label: {
                    Image(systemName: vm.isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(Color("InkMuted"))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color("Background"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Line"), lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        Button {
            Task { await vm.signIn() }
        } label: {
            ZStack {
                Text(LocalizedStringKey("login.submit"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(vm.isLoading ? 0 : 1)
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(vm.canSubmit ? Color("BrandGreen") : Color("InkMuted"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!vm.canSubmit)
    }
}

/// Opens iOS Settings → SSAMAU page, where the per-app Language
/// picker lives. Requires `CFBundleLocalizations` to be present in
/// the bundle Info.plist for the picker to appear.
private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
}

/// Bordered text field — used for the identifier field. Password field
/// builds its own to host the show/hide eye button.
private struct BorderedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color("Background"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Line"), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
}
