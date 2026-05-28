import SwiftUI

/// Head-mode members list — spec §9.2. Server auto-scopes to caller's
/// committee when access==head. Reused for Admin via AdminMembersView
/// (different title + the server returns broader scope).
struct HeadMembersView: View {
    /// True when this is the admin variant — broader scope, includes
    /// committee column in rows. Defaults to head (committee-scoped).
    var adminMode: Bool = false

    @StateObject private var vm = MembersListViewModel()
    @State private var inviteSheetRow: MemberAccountRow?
    @State private var revokeConfirmRow: MemberAccountRow?
    @State private var viewerRow: MemberAccountRow?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey(
                    adminMode ? "ap.tabs.members" : "hp.tabs.members"
                ))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(item: $inviteSheetRow) { row in
                    inviteSheet(for: row)
                        .iPadSheet(.large)
                }
                .sheet(item: $vm.pinInviteResult) { result in
                    pinResultSheet(result)
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
                .confirmationDialog(
                    LocalizedStringKey("hp.members.revoke_confirm"),
                    isPresented: revokeBinding,
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
    }

    private var revokeBinding: Binding<Bool> {
        Binding(
            get: { revokeConfirmRow != nil },
            set: { if !$0 { revokeConfirmRow = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if vm.rows.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage, vm.rows.isEmpty {
            errorState(err)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                searchBar
                filterChips
                if vm.filteredRows.isEmpty {
                    Text(LocalizedStringKey("hp.members.empty"))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGrey)
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.filteredRows) { row in
                            rowCard(row)
                        }
                    }
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.ssGrey)
            TextField(
                LocalizedStringKey("hp.members.search_placeholder"),
                text: $vm.searchText
            )
            .font(.ssBody)
            .foregroundStyle(Color.ssCharcoal)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ssGrey)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ssLight, lineWidth: 1)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MembersListViewModel.StatusFilter.allCases) { f in
                    chip(f)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(_ filter: MembersListViewModel.StatusFilter) -> some View {
        let selected = vm.statusFilter == filter
        return Button {
            vm.statusFilter = filter
        } label: {
            Text(LocalizedStringKey(filter.labelKey))
                .font(.ssCaption.weight(.semibold))
                .foregroundStyle(selected ? Color.ssCream : Color.ssGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.ssGreen : Color.ssPale)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func rowCard(_ row: MemberAccountRow) -> some View {
        // Tap the body (name/role/state) to open the viewer; the action
        // buttons live below and have their own tap targets so they
        // don't trigger the viewer.
        VStack(alignment: .leading, spacing: 8) {
            Button { viewerRow = row } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.displayName)
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssGreen)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if let role = MemberFieldMaps.roleLabel(row.memberClubRole) {
                                Text(role)
                                    .font(.ssCaption)
                                    .foregroundStyle(Color.ssCharcoal)
                            }
                            if adminMode, let committee = row.memberCommitteeName {
                                Text("·")
                                    .foregroundStyle(Color.ssGrey)
                                Text(committee)
                                    .font(.ssCaption)
                                    .foregroundStyle(Color.ssGrey)
                                    .lineLimit(1)
                            }
                        }
                        if let last = MemberFieldMaps.displayDate(row.lastLoginAt) {
                            Text(String(localized: "hp.members.last_login_prefix") + " " + last)
                                .font(.ssTiny)
                                .foregroundStyle(Color.ssGrey)
                        }
                    }
                    Spacer()
                    stateBadge(row.state)
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .buttonStyle(.plain)
            actionRow(row)
        }
        .padding(14)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func actionRow(_ row: MemberAccountRow) -> some View {
        // .active rows render nothing — no need for an empty HStack
        // taking up extra padding under the body.
        if row.state != .active {
            HStack(spacing: 8) {
                switch row.state {
                case .noAccount:
                    inviteAction(row)
                case .pendingInvite:
                    inviteAction(row)
                    revokeAction(row)
                case .active:
                    EmptyView()
                }
            }
        }
    }

    private func inviteAction(_ row: MemberAccountRow) -> some View {
        let busy = vm.inFlightMemberId == row.memberId
        return Button {
            inviteSheetRow = row
        } label: {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().tint(Color.ssGreen)
                } else {
                    Image(systemName: "envelope.badge")
                }
                Text(LocalizedStringKey(
                    row.state == .pendingInvite
                    ? "hp.members.resend_invite"
                    : "hp.members.invite_btn"
                ))
            }
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(Color.ssGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ssCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(vm.inFlightMemberId != nil)
    }

    private func revokeAction(_ row: MemberAccountRow) -> some View {
        Button(role: .destructive) {
            revokeConfirmRow = row
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text(LocalizedStringKey("hp.members.revoke_btn"))
            }
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ssCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(vm.inFlightMemberId != nil)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Invite sheet (email / PIN choice)

    private func inviteSheet(for row: MemberAccountRow) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.displayName)
                            .font(.ssH2)
                            .foregroundStyle(Color.ssGreen)
                        if let email = row.authEmail {
                            Text(email).font(.ssCaption).foregroundStyle(Color.ssGrey)
                        }
                    }

                    Text(LocalizedStringKey("hp.members.invite_intro"))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGrey)

                    Button {
                        // Dismiss this invite sheet FIRST. Without the leading
                        // dismiss, the toast-on-success briefly lands behind
                        // this still-presented sheet, and on email failure
                        // the user would be stuck on a sheet that already
                        // ran its action.
                        Task {
                            inviteSheetRow = nil
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            await vm.inviteByEmail(row)
                        }
                    } label: {
                        inviteOptionRow(
                            iconName: "envelope.fill",
                            titleKey: "hp.members.invite_email_title",
                            subtitleKey: "hp.members.invite_email_subtitle"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inFlightMemberId != nil)

                    Button {
                        // Dismiss this sheet BEFORE inviteByPin runs — the
                        // VM sets pinInviteResult on success which presents
                        // the PIN result sheet from the same anchor.
                        // Setting two .sheet(item:) bindings non-nil at the
                        // same time silently fails on iOS 16-17.
                        Task {
                            inviteSheetRow = nil
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            await vm.inviteByPin(row)
                        }
                    } label: {
                        inviteOptionRow(
                            iconName: "number.circle.fill",
                            titleKey: "hp.members.invite_pin_title",
                            subtitleKey: "hp.members.invite_pin_subtitle"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inFlightMemberId != nil)
                }
                .padding(20)
                .padding(.bottom, 80)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .ssToast(Binding(
                get: { vm.toast },
                set: { vm.toast = $0 }
            ))
            .navigationTitle(LocalizedStringKey("hp.members.invite_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) {
                        inviteSheetRow = nil
                    }
                    .foregroundStyle(Color.ssGrey)
                    .disabled(vm.inFlightMemberId != nil)
                }
            }
        }
    }

    private func inviteOptionRow(iconName: String, titleKey: String, subtitleKey: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(Color.ssGold)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                Text(LocalizedStringKey(subtitleKey))
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .foregroundStyle(Color.ssGrey)
                .font(.caption)
        }
        .padding(14)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PIN result sheet (shown ONCE after PIN invite)

    private func pinResultSheet(_ result: MembersListViewModel.PinInviteResult) -> some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.ssGold)
                Text(LocalizedStringKey("hp.members.pin_result_title"))
                    .font(.ssH2)
                    .foregroundStyle(Color.ssGreen)
                Text(result.memberName)
                    .font(.ssBody)
                    .foregroundStyle(Color.ssCharcoal)
                Text(result.pin)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.ssPale)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.ssGold, lineWidth: 1.5)
                    )
                Text(String(
                    format: NSLocalizedString("hp.members.pin_expires_fmt", comment: ""),
                    result.expiresHours
                ))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
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
            .ssToast(Binding(
                get: { vm.toast },
                set: { vm.toast = $0 }
            ))
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
        }
        .interactiveDismissDisabled(true)
    }

    private func errorState(_ message: String) -> some View {
        let display = message.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "err.unknown")
            : message
        return VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(display)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { Task { await vm.load() } } label: {
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
