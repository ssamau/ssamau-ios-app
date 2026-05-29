import SwiftUI

/// Thank-you emails — single + bulk-by-project. Reused for admin via
/// adminMode (server already scopes by committee for heads, full for
/// admin, so no client-side filtering needed beyond project picker).
struct ThanksView: View {
    var adminMode: Bool = false

    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = ThanksViewModel()
    @State private var sending: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey(
                    adminMode ? "ap.tabs.thanks" : "hp.tabs.thanks"
                ))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await refresh() }
                .task { await refresh() }
                .ssToast($vm.toast)
                .sheet(isPresented: $sending) {
                    SendThanksSheet(vm: vm, isPresented: $sending) {
                        await refresh()
                    }
                    .iPadSheet(.large)
                }
            Button { sending = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.badge")
                    Text(LocalizedStringKey("hp.thanks.send_btn"))
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
        // ⌘N opens the send-thanks sheet (iPad keyboard / Mac
        // Catalyst), mirroring the send FAB.
        .ssKeyboardShortcuts([SSKeyboardShortcut("n") { sending = true }])
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
                        Text(LocalizedStringKey("hp.thanks.empty"))
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
            TextField(LocalizedStringKey("hp.thanks.search_placeholder"),
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

    private func rowCard(_ row: ThanksRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.displayRecipient)
                    .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                Spacer()
                statusBadge(row.status ?? "")
            }
            if let project = row.projectName {
                Label(project, systemImage: "folder")
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
            }
            if let subj = row.subject {
                Text(subj).font(.ssCaption).foregroundStyle(Color.ssGrey).lineLimit(2)
            }
            if let date = MemberFieldMaps.displayDate(row.sentAt) {
                Label(date, systemImage: "calendar")
                    .font(.ssTiny).foregroundStyle(Color.ssGrey)
            }
            if row.recordedHours > 0 {
                Text(String(format: NSLocalizedString("hp.thanks.recorded_hours_fmt", comment: ""),
                            String(format: "%.1f", row.recordedHours)))
                    .font(.ssTiny).foregroundStyle(Color.ssGold)
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Sent":    return (.ssGreen, "common.status.sent")
            case "Pending": return (.ssGold,  "common.status.pending")
            case "Failed":  return (.red,     "common.status.failed")
            default:        return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Send sheet

private struct SendThanksSheet: View {
    @ObservedObject var vm: ThanksViewModel
    @Binding var isPresented: Bool
    /// Parent-supplied refresh callback that respects adminMode scope.
    let onSubmitted: () async -> Void

    @State private var mode: Mode = .single
    @State private var selectedProjectId: String = ""
    @State private var selectedMemberId: String = ""
    @State private var recipientEmail: String = ""
    @State private var subject: String = ""
    @State private var message: String = ""

    enum Mode: String, CaseIterable, Identifiable {
        case single, bulk
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Mode", selection: $mode) {
                        Text(LocalizedStringKey("hp.thanks.mode_single")).tag(Mode.single)
                        Text(LocalizedStringKey("hp.thanks.mode_bulk")).tag(Mode.bulk)
                    }
                    .pickerStyle(.segmented)

                    if mode == .single {
                        field("hp.thanks.field_member") {
                            Menu {
                                Button("—") {
                                    selectedMemberId = ""
                                    recipientEmail = ""
                                }
                                ForEach(vm.members
                                    .filter { $0.memberId != nil }
                                    .sorted { $0.displayName < $1.displayName }) { m in
                                    Button(m.displayName) {
                                        selectedMemberId = m.memberId ?? ""
                                        recipientEmail = m.authEmail ?? ""
                                    }
                                }
                            } label: {
                                pickerLabel(selectedMember?.displayName ?? "—")
                            }
                        }
                        field("hp.thanks.field_email") {
                            TextField("", text: $recipientEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(10)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    field("hp.thanks.field_project") {
                        Menu {
                            if mode == .single {
                                Button("—") { selectedProjectId = "" }
                            }
                            ForEach(vm.projects) { p in
                                Button(p.name) { selectedProjectId = p.id }
                            }
                        } label: {
                            pickerLabel(selectedProject?.name ?? "—")
                        }
                    }
                    if mode == .bulk {
                        Text(LocalizedStringKey("hp.thanks.bulk_hint"))
                            .font(.ssTiny).foregroundStyle(Color.ssGrey)
                    }
                    field("hp.thanks.field_subject") {
                        TextField("", text: $subject)
                            .padding(10)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("hp.thanks.field_message") {
                        TextEditor(text: $message)
                            .frame(minHeight: 140)
                            .padding(6)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }

                    Button {
                        Task {
                            let ok: Bool
                            if mode == .single {
                                ok = await vm.sendSingle(
                                    projectId: selectedProjectId.isEmpty ? nil : selectedProjectId,
                                    memberId: selectedMemberId.isEmpty ? nil : selectedMemberId,
                                    email: recipientEmail.trimmingCharacters(in: .whitespaces),
                                    subject: subject.trimmingCharacters(in: .whitespaces),
                                    message: message
                                )
                            } else {
                                ok = await vm.sendBulk(
                                    projectId: selectedProjectId,
                                    subject: subject.trimmingCharacters(in: .whitespaces),
                                    message: message
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
                            Text(LocalizedStringKey("common.send")).font(.ssBodyBold)
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
            .navigationTitle(LocalizedStringKey("hp.thanks.sheet_send_title"))
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

    private var canSubmit: Bool {
        let msgOk = !message.trimmingCharacters(in: .whitespaces).isEmpty
        if mode == .single {
            return msgOk && !recipientEmail.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return msgOk && !selectedProjectId.isEmpty
    }
    private var selectedProject: Project? {
        vm.projects.first { $0.id == selectedProjectId }
    }
    private var selectedMember: MemberAccountRow? {
        vm.members.first { $0.memberId == selectedMemberId }
    }
    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
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
