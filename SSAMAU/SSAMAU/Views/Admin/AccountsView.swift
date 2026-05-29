import SwiftUI

/// Admin Accounts tab — same backing data as AdminMembersView (users.list)
/// but presented with the account-state focus front and center: account
/// id, role, last login, account-state badge. Reuses MembersListViewModel
/// for the invite/revoke actions.
struct AccountsView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = MembersListViewModel()
    @State private var inviteSheetRow: MemberAccountRow?
    @State private var revokeConfirmRow: MemberAccountRow?
    @State private var viewerRow: MemberAccountRow?
    @State private var creatingAccount: Bool = false
    @State private var editingAccount: MemberAccountRow?
    @State private var deleteConfirmAccount: MemberAccountRow?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                    .iPadSheet(.large)
                }
                .sheet(item: $vm.pinInviteResult) { result in
                    PinResultSheet(result: result, vm: vm)
                        .iPadSheet(.small)
                }
                .sheet(item: $viewerRow) { row in
                    MemberProfileViewerSheet(
                        row: row,
                        isPresented: Binding(
                            get: { viewerRow != nil },
                            set: { if !$0 { viewerRow = nil } }
                        )
                    )
                    .iPadSheet(.large)
                }
                .sheet(isPresented: $creatingAccount) {
                    AccountFormSheet(
                        existing: nil, vm: vm,
                        isPresented: $creatingAccount,
                        currentUserIsSuperadmin: session.currentUser?.isSuperadmin == true
                    )
                    .iPadSheet(.xlarge)
                }
                .sheet(item: $editingAccount) { row in
                    AccountFormSheet(
                        existing: row, vm: vm,
                        isPresented: Binding(
                            get: { editingAccount != nil },
                            set: { if !$0 { editingAccount = nil } }
                        ),
                        currentUserIsSuperadmin: session.currentUser?.isSuperadmin == true
                    )
                    .iPadSheet(.xlarge)
                }
                .confirmationDialog(
                    LocalizedStringKey("ap.accounts.delete_confirm"),
                    isPresented: Binding(
                        get: { deleteConfirmAccount != nil },
                        set: { if !$0 { deleteConfirmAccount = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let row = deleteConfirmAccount, let accId = row.accountId {
                        Button(LocalizedStringKey("common.delete"), role: .destructive) {
                            Task {
                                await vm.deleteAccount(accountId: accId)
                                deleteConfirmAccount = nil
                            }
                        }
                    }
                    Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
                }

            Button { creatingAccount = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text(LocalizedStringKey("ap.accounts.add_btn"))
                }
                .font(.ssBodyBold).foregroundStyle(Color.ssCream)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.ssGreen).clipShape(Capsule()).shadow(radius: 4)
            }
            .padding(20)
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
        // ⌘N opens the create-account sheet (iPad keyboard / Mac
        // Catalyst), mirroring the always-available FAB.
        .ssKeyboardShortcuts([SSKeyboardShortcut("n") { creatingAccount = true }])
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
                        LazyVGrid(columns: SSAdaptiveColumns.cards, spacing: 8) {
                            ForEach(vm.filteredRows) { row in
                                rowCard(row).ssHover()
                            }
                        }
                    }
                }
                .ipadContentWidth()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private func rowCard(_ row: MemberAccountRow) -> some View {
        // Body opens the viewer; small "actions" button opens the
        // invite/revoke sheet. Splits the two intents so a tap to "see
        // who this is" doesn't immediately demand a destructive action.
        VStack(alignment: .leading, spacing: 8) {
            Button { viewerRow = row } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.displayName)
                            .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                            .multilineTextAlignment(.leading)
                        if let role = row.accessLevel {
                            Text(role.capitalized)
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
                    Spacer()
                    stateBadge(row.state)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Spacer()
                // Edit + delete only when there's an account (accountId != nil).
                // canEditAccount also blocks admins from editing superadmin rows.
                if let _ = row.accountId, canEditAccount(row) {
                    Button { editingAccount = row } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                            Text(LocalizedStringKey("common.edit"))
                        }
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(Color.ssGreen)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.ssCream)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive) {
                        deleteConfirmAccount = row
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text(LocalizedStringKey("common.delete"))
                        }
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.ssCream)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.red.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                // Invite / resend only when there's no active account.
                if row.state != .active {
                    Button { inviteSheetRow = row } label: {
                        HStack(spacing: 4) {
                            Image(systemName: row.state == .pendingInvite
                                  ? "arrow.clockwise"
                                  : "envelope.badge")
                            Text(LocalizedStringKey(row.state == .pendingInvite
                                ? "hp.members.resend_invite"
                                : "hp.members.invite_btn"))
                        }
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(Color.ssGreen)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.ssCream)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Server: an admin can't touch a superadmin row. Mirror that on
    /// the client so the buttons don't appear in the first place; the
    /// server is still the authority and will 403 on bypass attempts.
    private func canEditAccount(_ row: MemberAccountRow) -> Bool {
        let target = row.accessLevel ?? "member"
        if target == "superadmin" {
            return session.currentUser?.isSuperadmin == true
        }
        return true
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
                            // Dismiss this sheet before the VM action so
                            // toast + (for PIN) the result sheet present
                            // cleanly. See HeadMembersView for context.
                            Task {
                                onClose()
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                await vm.inviteByEmail(row)
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
                                onClose()
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                await vm.inviteByPin(row)
                            }
                        } label: {
                            actionRow(icon: "number.circle.fill",
                                      title: "hp.members.invite_pin_title",
                                      subtitle: "hp.members.invite_pin_subtitle")
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.inFlightMemberId != nil)

                    case .active:
                        // Resolve the date once up-front; passing
                        // `flatMap(MemberFieldMaps.displayDate)` as a
                        // method ref into String(format:) triggers a
                        // strict-concurrency warning that's harmless but
                        // noisy.
                        let lastLogin = MemberFieldMaps.displayDate(row.lastLoginAt) ?? "—"
                        Text(String(
                            format: NSLocalizedString("ap.accounts.active_with_last_login_fmt", comment: ""),
                            lastLogin
                        ))
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

// MARK: - Manual account create / update form

/// Form for admin-driven account provisioning outside the invite flow.
/// Create: username, password, optional member_id, access level.
/// Edit: username, member_id (with unlink), access level (no password
/// change — password reset goes through the dedicated reset flow).
private struct AccountFormSheet: View {
    let existing: MemberAccountRow?
    @ObservedObject var vm: MembersListViewModel
    @Binding var isPresented: Bool
    let currentUserIsSuperadmin: Bool

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var memberId: String = ""
    @State private var accessLevel: String = "member"
    @State private var inFlight: Bool = false

    /// Member candidates for the link picker. Only members WITHOUT an
    /// active account show up in create mode — they're the ones who
    /// can legitimately get a new account. In edit mode we also include
    /// the currently-linked member so the picker preselects correctly.
    private var memberCandidates: [MemberAccountRow] {
        vm.rows.filter { row in
            guard row.memberId != nil else { return false }
            if existing != nil && row.memberId == existing?.memberId { return true }
            return row.accountId == nil
        }.sorted { $0.displayName < $1.displayName }
    }

    private var canSubmit: Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if existing == nil {
            // Create needs a password (>= 6 chars per server rule).
            return password.count >= 6
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("ap.accounts.field_username") {
                        TextField("", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if existing == nil {
                        field("ap.accounts.field_password") {
                            SecureField("", text: $password)
                                .padding(10).background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(LocalizedStringKey("ap.accounts.field_password_hint"))
                                .font(.ssTiny).foregroundStyle(Color.ssGrey)
                        }
                    } else {
                        Text(LocalizedStringKey("ap.accounts.password_unchanged_hint"))
                            .font(.ssTiny).foregroundStyle(Color.ssGrey)
                    }
                    field("ap.accounts.field_access_level") {
                        Picker(selection: $accessLevel) {
                            Text(LocalizedStringKey("ap.accounts.access_volunteer")).tag("volunteer")
                            Text(LocalizedStringKey("ap.accounts.access_member")).tag("member")
                            Text(LocalizedStringKey("ap.accounts.access_head")).tag("head")
                            Text(LocalizedStringKey("ap.accounts.access_admin")).tag("admin")
                            if currentUserIsSuperadmin {
                                Text(LocalizedStringKey("ap.accounts.access_superadmin")).tag("superadmin")
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .tint(Color.ssGreen)
                    }
                    field("ap.accounts.field_member") {
                        Menu {
                            Button(LocalizedStringKey("ap.accounts.no_linked_member")) {
                                memberId = ""
                            }
                            ForEach(memberCandidates) { m in
                                if let mid = m.memberId {
                                    Button(m.displayName) { memberId = mid }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedMemberDisplayName)
                                    .font(.ssBody)
                                    .foregroundStyle(memberId.isEmpty ? Color.ssGrey : Color.ssCharcoal)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption).foregroundStyle(Color.ssGrey)
                            }
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(LocalizedStringKey("ap.accounts.member_link_hint"))
                            .font(.ssTiny).foregroundStyle(Color.ssGrey)
                    }

                    Button { submit() } label: {
                        HStack {
                            if inFlight { ProgressView().tint(Color.ssCream) }
                            Text(LocalizedStringKey("common.save")).font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(canSubmit ? Color.ssGreen : Color.ssGrey)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canSubmit || inFlight)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(existing == nil
                ? "ap.accounts.sheet_create_title"
                : "ap.accounts.sheet_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
        .onAppear { prefill() }
    }

    private var selectedMemberDisplayName: String {
        if memberId.isEmpty {
            return NSLocalizedString("ap.accounts.no_linked_member", comment: "")
        }
        return vm.rows.first(where: { $0.memberId == memberId })?.displayName ?? memberId
    }

    private func prefill() {
        guard let e = existing else {
            accessLevel = "member"
            return
        }
        username = e.username ?? ""
        memberId = e.memberId ?? ""
        accessLevel = e.accessLevel ?? "member"
    }

    private func submit() {
        Task {
            inFlight = true
            defer { inFlight = false }
            let u = username.trimmingCharacters(in: .whitespaces).lowercased()
            if let existing, let accId = existing.accountId {
                // Three-state member_id arg for the VM:
                //   .none           — field wasn't touched, keep existing.
                //   .some(.none)    — explicit unlink (sends NULL).
                //   .some(.some(x)) — relink to member x.
                let memberChanged = memberId != (existing.memberId ?? "")
                let memberArg: String??
                if memberChanged {
                    let trimmed = memberId.trimmingCharacters(in: .whitespaces)
                    memberArg = trimmed.isEmpty
                        ? Optional<String>.none as String??
                        : Optional<String>.some(trimmed) as String??
                } else {
                    memberArg = nil
                }
                let ok = await vm.updateAccount(
                    accountId: accId,
                    username: u == (existing.username ?? "") ? nil : u,
                    memberId: memberArg,
                    accessLevel: accessLevel == (existing.accessLevel ?? "") ? nil : accessLevel
                )
                if ok { isPresented = false }
            } else {
                let ok = await vm.createAccount(
                    username: u,
                    password: password,
                    memberId: memberId.isEmpty ? nil : memberId,
                    accessLevel: accessLevel
                )
                if ok { isPresented = false }
            }
        }
    }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key)).font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
}
