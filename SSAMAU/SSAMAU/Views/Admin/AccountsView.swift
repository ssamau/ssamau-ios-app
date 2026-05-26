import SwiftUI

/// Admin Accounts tab — same backing data as AdminMembersView (users.list)
/// but presented with the account-state focus front and center: account
/// id, role, last login, account-state badge. Reuses MembersListViewModel
/// for the invite/revoke actions.
struct AccountsView: View {
    @StateObject private var vm = MembersListViewModel()
    @State private var inviteSheetRow: MemberAccountRow?
    @State private var revokeConfirmRow: MemberAccountRow?

    var body: some View {
        content
            .navigationTitle(LocalizedStringKey("ap.tabs.accounts"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .ssToast($vm.toast)
            .sheet(item: $inviteSheetRow) { row in
                AccountActionsSheet(row: row, vm: vm) {
                    inviteSheetRow = nil
                }
            }
            .sheet(item: $vm.pinInviteResult) { result in
                PinResultSheet(result: result, vm: vm)
            }
            .confirmationDialog(
                LocalizedStringKey("hp.members.revoke_confirm"),
                isPresented: Binding(
                    get: { revokeConfirmRow != nil },
                    set: { if !$0 { revokeConfirmRow = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let row = revokeConfirmRow {
                    Button(LocalizedStringKey("hp.members.revoke_btn"),
                           role: .destructive) {
                        Task { await vm.revokeInvite(row) }
                    }
                }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
            }
    }

    @ViewBuilder
    private var content: some View {
        if vm.rows.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.ssGrey)
                        TextField(LocalizedStringKey("ap.accounts.search_placeholder"),
                                  text: $vm.searchText)
                            .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    .padding(12)
                    .background(Color.ssPale)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.ssLight, lineWidth: 1))

                    if vm.filteredRows.isEmpty {
                        Text(LocalizedStringKey("ap.accounts.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.filteredRows) { row in
                                rowCard(row)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private func rowCard(_ row: MemberAccountRow) -> some View {
        Button { inviteSheetRow = row } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.displayName)
                        .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                    Spacer()
                    stateBadge(row.state)
                }
                if let role = row.accessLevel {
                    Text("\(role)")
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.ssGold)
                        .clipShape(Capsule())
                }
                if let u = row.username {
                    Text(u).font(.ssTiny.monospaced()).foregroundStyle(Color.ssGrey)
                }
                if let committee = row.memberCommitteeName {
                    Label(committee, systemImage: "building.2")
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
                if let last = MemberFieldMaps.displayDate(row.lastLoginAt) {
                    Text(String(localized: "hp.members.last_login_prefix") + " " + last)
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssPale)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func stateBadge(_ state: MemberAccountRow.State) -> some View {
        let (color, key): (Color, String) = {
            switch state {
            case .noAccount:     return (.ssGrey,  "hp.members.state_no_account")
            case .pendingInvite: return (.ssGold,  "hp.members.state_pending")
            case .active:        return (.ssGreen, "hp.members.state_active")
            }
        }()
        return Text(LocalizedStringKey(key))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Account actions

private struct AccountActionsSheet: View {
    let row: MemberAccountRow
    @ObservedObject var vm: MembersListViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.displayName)
                            .font(.ssH2).foregroundStyle(Color.ssGreen)
                        if let email = row.authEmail {
                            Text(email).font(.ssCaption).foregroundStyle(Color.ssGrey)
                        }
                        if let username = row.username {
                            Text(username).font(.ssTiny.monospaced())
                                .foregroundStyle(Color.ssGrey)
                        }
                        GoldRule(width: 32)
                    }

                    switch row.state {
                    case .noAccount, .pendingInvite:
                        Text(LocalizedStringKey("hp.members.invite_intro"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)

                        Button {
                            Task {
                                await vm.inviteByEmail(row)
                                onClose()
                            }
                        } label: {
                            actionRow(icon: "envelope.fill",
                                      title: "hp.members.invite_email_title",
                                      subtitle: "hp.members.invite_email_subtitle")
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.inFlightMemberId != nil)

                        Button {
                            Task {
                                await vm.inviteByPin(row)
                                onClose()
                            }
                        } label: {
                            actionRow(icon: "number.circle.fill",
                                      title: "hp.members.invite_pin_title",
                                      subtitle: "hp.members.invite_pin_subtitle")
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.inFlightMemberId != nil)

                    case .active:
                        Text("Account is active — last login \(row.lastLoginAt.flatMap(MemberFieldMaps.displayDate) ?? "—")")
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.members.invite_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { onClose() }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(Color.ssGold)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.ssBodyBold).foregroundStyle(Color.ssCharcoal)
                Text(LocalizedStringKey(subtitle))
                    .font(.ssCaption).foregroundStyle(Color.ssGrey)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .foregroundStyle(Color.ssGrey).font(.caption)
        }
        .padding(14)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PinResultSheet: View {
    let result: MembersListViewModel.PinInviteResult
    @ObservedObject var vm: MembersListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "key.fill")
                    .font(.system(size: 36)).foregroundStyle(Color.ssGold)
                Text(LocalizedStringKey("hp.members.pin_result_title"))
                    .font(.ssH2).foregroundStyle(Color.ssGreen)
                Text(result.memberName)
                    .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                Text(result.pin)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.ssPale)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ssGold, lineWidth: 1.5))
                Button {
                    UIPasteboard.general.string = result.pin
                    vm.toast = .info(ErrorLocalization.localize("common.copied"))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text(LocalizedStringKey("hp.members.copy_pin"))
                    }
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.ssGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding(24)
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.members.pin_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.ok")) {
                        vm.pinInviteResult = nil
                    }
                    .foregroundStyle(Color.ssGreen)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
        .interactiveDismissDisabled(true)
    }
}
