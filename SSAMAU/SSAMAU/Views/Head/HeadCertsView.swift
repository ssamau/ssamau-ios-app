import SwiftUI

/// Head + Admin certificates view — spec §9.9. List + issue (single)
/// + bulkIssue (per project, fans out across every uncovered
/// participant). Reuses Certificate model from member-side.
struct HeadCertsView: View {
    var adminMode: Bool = false

    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = HeadCertsViewModel()
    @State private var issuing: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey(
                    adminMode ? "ap.tabs.certs" : "hp.tabs.certs"
                ))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await refresh() }
                .task { await refresh() }
                .ssToast($vm.toast)
                .sheet(isPresented: $issuing) {
                    IssueCertSheet(vm: vm, isPresented: $issuing) {
                        // Parent owns the committee scope (adminMode-aware);
                        // refresh from here so the sheet doesn't have to
                        // know which mode it's in.
                        await refresh()
                    }
                    .iPadSheet(.large)
                }
            Button { issuing = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rosette")
                    Text(LocalizedStringKey("hp.certs.issue_btn"))
                }
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssCream)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.ssGreen)
                .clipShape(Capsule())
                .shadow(radius: 4)
            }
            .padding(20)
        }
        // ⌘N opens the issue-certificate sheet (iPad keyboard / Mac
        // Catalyst), mirroring the issue FAB.
        .ssKeyboardShortcuts([SSKeyboardShortcut("n") { issuing = true }])
    }

    private func refresh() async {
        await vm.load(committeeId: adminMode ? nil : session.currentUser?.committeeId)
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
                    searchBar
                    if vm.filteredRows.isEmpty {
                        Text(LocalizedStringKey("hp.certs.empty"))
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
                .padding(.bottom, 80)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.ssGrey)
            TextField(LocalizedStringKey("hp.certs.search_placeholder"),
                      text: $vm.searchText)
                .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        .padding(12)
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ssLight, lineWidth: 1)
        )
    }

    private func rowCard(_ c: Certificate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(c.displayRecipient)
                    .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                Spacer()
                if let h = c.hours, h > 0 {
                    Label(String(format: "%.1f h", h), systemImage: "clock")
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(Color.ssGold)
                }
            }
            if let proj = c.projectName {
                Label(proj, systemImage: "folder")
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
            }
            if let role = c.role, !role.isEmpty {
                Text(role).font(.ssTiny).foregroundStyle(Color.ssGrey)
            }
            HStack(spacing: 12) {
                if let d = MemberFieldMaps.displayDate(c.issuedAt) {
                    Label(d, systemImage: "calendar")
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
                Label(c.certCode, systemImage: "barcode")
                    .font(.ssTiny.monospaced()).foregroundStyle(Color.ssGrey)
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct IssueCertSheet: View {
    @ObservedObject var vm: HeadCertsViewModel
    @Binding var isPresented: Bool
    /// Parent-supplied callback that knows the correct committee scope.
    /// Called after a successful issue so the parent list refreshes
    /// without the sheet having to know about adminMode.
    let onSubmitted: () async -> Void

    @State private var mode: Mode = .single
    @State private var selectedProjectId: String = ""
    @State private var selectedMemberId: String = ""
    @State private var recipientName: String = ""
    @State private var recipientEmail: String = ""
    @State private var role: String = ""

    enum Mode: String, CaseIterable, Identifiable {
        case single, bulk
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Mode", selection: $mode) {
                        Text(LocalizedStringKey("hp.certs.mode_single")).tag(Mode.single)
                        Text(LocalizedStringKey("hp.certs.mode_bulk")).tag(Mode.bulk)
                    }
                    .pickerStyle(.segmented)

                    field("hp.certs.field_project") {
                        Menu {
                            // Only Completed projects are eligible — the
                            // server (certs.ts) rejects issuance for any
                            // other status with err.business.project_not_complete
                            // (cross-repo cert gate, 2026-05-28). Filtering
                            // here keeps the picker honest so the head
                            // doesn't pick an ineligible project and hit a 409.
                            ForEach(completedProjects) { p in
                                Button(p.name) { selectedProjectId = p.id }
                            }
                        } label: {
                            pickerLabel(selectedProject?.name ?? "—")
                        }
                    }

                    if mode == .single {
                        field("hp.certs.field_member") {
                            Menu {
                                Button("—") {
                                    selectedMemberId = ""
                                    recipientName = ""
                                    recipientEmail = ""
                                }
                                ForEach(vm.members
                                    .filter { $0.memberId != nil }
                                    .sorted { $0.displayName < $1.displayName }) { m in
                                    Button(m.displayName) {
                                        selectedMemberId = m.memberId ?? ""
                                        recipientName = m.displayName
                                        recipientEmail = m.authEmail ?? ""
                                    }
                                }
                            } label: {
                                pickerLabel(selectedMember?.displayName ?? "—")
                            }
                        }
                        field("hp.certs.field_recipient") {
                            TextField("", text: $recipientName)
                                .font(.ssBody)
                                .foregroundStyle(Color.ssCharcoal)
                                .padding(10)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        field("hp.certs.field_email") {
                            TextField("", text: $recipientEmail)
                                .font(.ssBody)
                                .foregroundStyle(Color.ssCharcoal)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(10)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        // Hours field removed: the server now DERIVES cert
                        // hours from the member's FinalApproved hours for the
                        // project and ignores any client-sent value (cert
                        // governance fix, ticket SUP_3RT6RJRC, web commit
                        // 266046d). A free-type field here would be a no-op
                        // that misleads the issuer, so it's gone — the issued
                        // certificate shows the authoritative server figure.
                    }
                    field("hp.certs.field_role") {
                        TextField("", text: $role)
                            .font(.ssBody)
                            .foregroundStyle(Color.ssCharcoal)
                            .padding(10)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        Task {
                            let ok: Bool
                            if mode == .single {
                                ok = await vm.issueSingle(
                                    projectId: selectedProjectId,
                                    memberId: selectedMemberId.isEmpty ? nil : selectedMemberId,
                                    recipientName: recipientName.trimmingCharacters(in: .whitespaces),
                                    recipientEmail: recipientEmail.trimmingCharacters(in: .whitespaces),
                                    role: role.trimmingCharacters(in: .whitespaces),
                                    // Hours are server-derived now; the client
                                    // value is ignored, so send nil.
                                    hours: nil
                                )
                            } else {
                                ok = await vm.issueBulk(
                                    projectId: selectedProjectId,
                                    role: role.trimmingCharacters(in: .whitespaces)
                                )
                            }
                            if ok {
                                await onSubmitted()
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack {
                            if vm.inFlight { ProgressView().tint(Color.ssCream) }
                            Text(LocalizedStringKey("hp.certs.issue_btn")).font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(canSubmit ? Color.ssGreen : Color.ssGrey)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlight || !canSubmit)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.certs.sheet_issue_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
    }

    /// Cert-eligible projects: only those whose status is the canonical
    /// finished value ("Completed"). Mirrors the server cert gate so the
    /// picker never offers a project that issuance would 409 on.
    private var completedProjects: [Project] {
        vm.projects.filter { $0.projectStatus == "Completed" }
    }

    private var canSubmit: Bool {
        guard !selectedProjectId.isEmpty else { return false }
        // Ticket SUP_BNYPAHUK: never issue a certificate without a role —
        // it must always state the person's role (their committee role or
        // a specific one). Enforced for both single and bulk here so the
        // Issue button stays disabled until a role is entered. NOTE: this
        // is a client-side guard only; the server (certs.ts) still inserts
        // `role || null` without validation, so the authoritative rule
        // should also be added web-side (reject empty role) to cover the
        // web client and any other caller.
        guard !role.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // Bulk mode just needs the project (+ role above) — the server
        // iterates participants. Single mode needs a recipient identity:
        // either a picked member, or a manually-typed name + email.
        if mode == .bulk { return true }
        if !selectedMemberId.isEmpty { return true }
        let nameOk = !recipientName.trimmingCharacters(in: .whitespaces).isEmpty
        let emailOk = !recipientEmail.trimmingCharacters(in: .whitespaces).isEmpty
        return nameOk && emailOk
    }
    private var selectedProject: Project? { vm.projects.first { $0.id == selectedProjectId } }
    private var selectedMember: MemberAccountRow? { vm.members.first { $0.memberId == selectedMemberId } }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key)).font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
    private func pickerLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.ssBody).foregroundStyle(Color.ssCharcoal)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.ssGrey)
        }
        .padding(10)
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
