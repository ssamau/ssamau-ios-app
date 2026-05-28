import SwiftUI

/// Member-mode certificates list — spec §8.8.
struct CertificatesView: View {
    @StateObject private var vm = CertificatesViewModel()
    @State private var presented: Certificate?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.certs"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .sheet(item: $presented) { cert in
                    CertificateDetailSheet(certificate: cert) {
                        presented = nil
                    }
                    .iPadSheet(.large)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.certificates.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let error = vm.errorMessage, vm.certificates.isEmpty {
            errorState(error)
        } else if vm.certificates.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVGrid(columns: SSAdaptiveColumns.cards, spacing: 12) {
                ForEach(vm.certificates) { cert in
                    row(cert)
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func row(_ cert: Certificate) -> some View {
        Button {
            presented = cert
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rosette")
                    .font(.title)
                    .foregroundStyle(Color.ssGold)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cert.displayProject)
                        .font(.ssBodyBold)
                        .foregroundStyle(Color.ssGreen)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        if let role = cert.role {
                            Text(role)
                                .font(.ssCaption)
                                .foregroundStyle(Color.ssCharcoal)
                        }
                        if let h = cert.hours {
                            Text("·")
                                .foregroundStyle(Color.ssGrey)
                            Text(String(format: "%.0fh", h))
                                .font(.ssCaption)
                                .foregroundStyle(Color.ssGrey)
                        }
                    }
                    if let date = MemberFieldMaps.displayDate(cert.issuedAt) {
                        Text(date)
                            .font(.ssTiny)
                            .foregroundStyle(Color.ssGrey)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.ssGrey)
                    .font(.caption)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.certs.empty"))
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(message)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.load() }
            } label: {
                Text(LocalizedStringKey("common.retry"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.ssGreen)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}

// MARK: - Detail sheet

private struct CertificateDetailSheet: View {
    let certificate: Certificate
    let onDismiss: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    certCard
                    if let url = certificate.verifyURL {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(LocalizedStringKey("mp.certs.share_verify"))
                            }
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssCream)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.ssGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .sheet(isPresented: $showShareSheet) {
                            ShareSheet(items: [url])
                        }

                        Text(LocalizedStringKey("mp.certs.verify_hint"))
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("mp.certs.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { onDismiss() }
                        .foregroundStyle(Color.ssGrey)
                }
            }
        }
    }

    /// Brand-styled "certificate" surface — deep-green field with gold
    /// motif + recipient + project + hours. Recreates the brand-guide
    /// certificate aesthetic (page 16) at iPhone scale.
    private var certCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "rosette")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.certs.cert_of_appreciation"))
                .font(.ssLatinLabel)
                .tracking(3)
                .foregroundStyle(Color.ssGold)
            GoldRule(width: 50)
            Text(certificate.displayRecipient)
                .font(.ssH1)
                .foregroundStyle(Color.ssCream)
                .multilineTextAlignment(.center)
            VStack(spacing: 4) {
                if let role = certificate.role {
                    Text(role)
                        .font(.ssBody)
                        .foregroundStyle(Color.ssCream)
                }
                Text(certificate.displayProject)
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssCream.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            if let h = certificate.hours, h > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                    Text(String(format: "%.0f hours", h))
                }
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssGold)
                .padding(.top, 4)
            }
            GoldRule(width: 30)
            VStack(spacing: 2) {
                Text(LocalizedStringKey("mp.certs.cert_code_label"))
                    .font(.ssTiny)
                    .foregroundStyle(Color.ssCream.opacity(0.7))
                Text(certificate.certCode)
                    .font(.ssCaption.monospaced())
                    .foregroundStyle(Color.ssCream)
            }
            if let date = MemberFieldMaps.displayDate(certificate.issuedAt) {
                Text(date)
                    .font(.ssTiny)
                    .foregroundStyle(Color.ssCream.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.ssGreenDark)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ssGold, lineWidth: 2)
                .padding(6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Share sheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
