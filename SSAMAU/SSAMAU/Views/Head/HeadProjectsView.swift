import SwiftUI

/// Head-mode projects/events list — spec §9.5. Server's `getProjects`
/// returns everything; we filter client-side to the head's committee.
/// Admin variant uses the same view with `adminMode = true` to see
/// every committee + edit any project.
struct HeadProjectsView: View {
    var adminMode: Bool = false

    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = HeadProjectsViewModel()
    @State private var editTarget: Project?
    @State private var creatingNew: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey(adminMode ? "ap.tabs.projects" : "hp.tabs.projects"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await refresh() }
                .task { await refresh() }
                .ssToast($vm.toast)
                .sheet(isPresented: $creatingNew) {
                    ProjectFormSheet(
                        existing: nil,
                        vm: vm,
                        defaultCommittee: session.currentUser?.committeeId,
                        isPresented: $creatingNew
                    )
                    .iPadSheet(.large)
                }
                .sheet(item: $editTarget) { project in
                    ProjectFormSheet(
                        existing: project,
                        vm: vm,
                        defaultCommittee: project.owningCommitteeId,
                        isPresented: Binding(
                            get: { editTarget != nil },
                            set: { if !$0 { editTarget = nil } }
                        )
                    )
                    .iPadSheet(.large)
                }

            // Floating action button (only when we have a committee to scope to;
            // admin mode lets superadmin create any project)
            if canCreate {
                Button {
                    creatingNew = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(LocalizedStringKey("hp.projects.create_btn"))
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
        }
        // ⌘N opens the create sheet (iPad keyboard / Mac Catalyst),
        // mirroring the FAB and gated on the same permission.
        .ssKeyboardShortcuts(
            canCreate ? [SSKeyboardShortcut("n") { creatingNew = true }] : []
        )
    }

    private var canCreate: Bool {
        // Head needs their own committee_id; admin always.
        adminMode || (session.currentUser?.committeeId != nil)
    }

    private func refresh() async {
        if !adminMode {
            vm.committeeFilter = session.currentUser?.committeeId
        }
        await vm.load()
    }

    @ViewBuilder
    private var content: some View {
        if vm.projects.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage, vm.projects.isEmpty {
            errorState(err)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                searchBar
                if vm.filteredProjects.isEmpty {
                    Text(LocalizedStringKey("hp.projects.empty"))
                        .font(.ssCaption).foregroundStyle(Color.ssGrey)
                        .padding(.vertical, 40)
                } else {
                    LazyVGrid(columns: SSAdaptiveColumns.cards, spacing: 10) {
                        ForEach(vm.filteredProjects) { project in
                            rowCard(project).ssHover()
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.ssGrey)
            TextField(LocalizedStringKey("hp.projects.search_placeholder"),
                      text: $vm.searchText)
                .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ssGrey)
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

    private func rowCard(_ project: Project) -> some View {
        let canEdit = adminMode || project.owningCommitteeId == session.currentUser?.committeeId
        return Button {
            if canEdit { editTarget = project }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                            .multilineTextAlignment(.leading)
                        if let type = project.projectType {
                            Text(typeLabel(type))
                                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                        }
                    }
                    Spacer()
                    statusBadge(project.projectStatus ?? "Planned")
                }
                HStack(spacing: 12) {
                    if let date = MemberFieldMaps.displayDate(project.eventDate) {
                        Label(date, systemImage: "calendar")
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                    if let loc = project.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .lineLimit(1)
                    }
                }
                if !canEdit {
                    Text(LocalizedStringKey("hp.projects.cant_edit_other"))
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssPale)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(canEdit ? 1 : 0.7)
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Active":    return (.ssGreen, "hp.projects.status_active")
            case "Done":      return (.ssGrey,  "hp.projects.status_done")
            case "Cancelled": return (.red,     "hp.projects.status_cancelled")
            default:          return (.ssGold,  "hp.projects.status_planned")
            }
        }()
        return Text(NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private func typeLabel(_ raw: String) -> String {
        switch raw {
        case "Event":      return NSLocalizedString("hp.projects.type_event", comment: "")
        case "Initiative": return NSLocalizedString("hp.projects.type_initiative", comment: "")
        case "Meeting":    return NSLocalizedString("hp.projects.type_meeting", comment: "")
        default:           return raw
        }
    }

    private func errorState(_ message: String) -> some View {
        let display = message.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "err.unknown") : message
        return VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(Color.ssGold)
            Text(display).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { Task { await vm.load() } } label: {
                Text(LocalizedStringKey("common.retry"))
                    .font(.ssBodyBold).foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.ssGreen).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}

// MARK: - ProjectFormSheet

private struct ProjectFormSheet: View {
    let existing: Project?
    @ObservedObject var vm: HeadProjectsViewModel
    let defaultCommittee: String?
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var projectType: String = "Event"
    @State private var status: String = "Planned"
    @State private var eventDate: Date = Date()
    @State private var hasEventDate: Bool = false
    @State private var startTime: String = ""
    @State private var endTime: String = ""
    @State private var location: String = ""
    @State private var description: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field(label: "hp.projects.field_name") {
                        TextField("", text: $name)
                            .textInputAutocapitalization(.words)
                            .padding(10)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("hp.projects.field_type"))
                                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            Picker(selection: $projectType) {
                                Text(LocalizedStringKey("hp.projects.type_event")).tag("Event")
                                Text(LocalizedStringKey("hp.projects.type_initiative")).tag("Initiative")
                                Text(LocalizedStringKey("hp.projects.type_meeting")).tag("Meeting")
                                Text(LocalizedStringKey("hp.projects.type_other")).tag("Other")
                            } label: { EmptyView() }
                            .pickerStyle(.menu)
                            .tint(Color.ssGreen)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("hp.projects.field_status"))
                                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            Picker(selection: $status) {
                                Text(LocalizedStringKey("hp.projects.status_planned")).tag("Planned")
                                Text(LocalizedStringKey("hp.projects.status_active")).tag("Active")
                                Text(LocalizedStringKey("hp.projects.status_done")).tag("Done")
                                Text(LocalizedStringKey("hp.projects.status_cancelled")).tag("Cancelled")
                            } label: { EmptyView() }
                            .pickerStyle(.menu)
                            .tint(Color.ssGreen)
                        }
                    }
                    Toggle(isOn: $hasEventDate.animation()) {
                        Text(LocalizedStringKey("hp.projects.field_date"))
                            .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                    }
                    .tint(Color.ssGreen)
                    if hasEventDate {
                        DatePicker("", selection: $eventDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    HStack {
                        field(label: "hp.projects.field_start") {
                            TextField("18:00", text: $startTime)
                                .keyboardType(.numbersAndPunctuation)
                                .padding(10)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        field(label: "hp.projects.field_end") {
                            TextField("20:00", text: $endTime)
                                .keyboardType(.numbersAndPunctuation)
                                .padding(10)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    field(label: "hp.projects.field_location") {
                        TextField("", text: $location)
                            .padding(10)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field(label: "hp.projects.field_description") {
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .padding(6)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }
                    field(label: "hp.projects.field_notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .padding(6)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }

                    Button {
                        Task {
                            let ok = await vm.createOrUpdate(
                                existing: existing,
                                name: name.trimmingCharacters(in: .whitespaces),
                                type: projectType,
                                status: status,
                                eventDate: hasEventDate ? eventDate : nil,
                                startTime: startTime.trimmingCharacters(in: .whitespaces),
                                endTime: endTime.trimmingCharacters(in: .whitespaces),
                                location: location.trimmingCharacters(in: .whitespaces),
                                description: description.trimmingCharacters(in: .whitespaces),
                                notes: notes.trimmingCharacters(in: .whitespaces),
                                owningCommitteeId: defaultCommittee
                            )
                            if ok { isPresented = false }
                        }
                    } label: {
                        HStack {
                            if vm.inFlightProjectId != nil {
                                ProgressView().tint(Color.ssCream)
                            }
                            Text(LocalizedStringKey("hp.projects.save_btn"))
                                .font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.ssGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlightProjectId != nil ||
                              name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(
                existing == nil
                    ? "hp.projects.sheet_create_title"
                    : "hp.projects.sheet_edit_title"
            ))
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

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(label))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }

    private func prefill() {
        guard let p = existing else {
            // Defaults for new
            return
        }
        name        = p.name
        projectType = p.projectType ?? "Event"
        status      = p.projectStatus ?? "Planned"
        if let parsed = MemberFieldMaps.parseServerDate(p.eventDate) {
            eventDate = parsed
            hasEventDate = true
        }
        startTime   = (p.startTime ?? "").prefix(5).description
        endTime     = (p.endTime   ?? "").prefix(5).description
        location    = p.location    ?? ""
        description = p.description ?? ""
        notes       = p.notes       ?? ""
    }
}
