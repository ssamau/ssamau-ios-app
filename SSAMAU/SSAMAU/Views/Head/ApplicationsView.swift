import SwiftUI

/// Head + Admin applications queue. Server scopes the list to caller's
/// committee for heads; admin sees everything. adminMode adds the
/// "Assign committee" action for PendingTriage rows.
struct ApplicationsView: View {
    var adminMode: Bool = false

    @StateObject private var vm = ApplicationsViewModel()
    @State private var selected: Application?

    var body: some View {
        content
            .navigationTitle(LocalizedStringKey(
                adminMode ? "ap.tabs.applications" : "hp.tabs.applications"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .ssToast($vm.toast)
            .sheet(item: $selected) { app in
                ApplicationDetailSheet(
                    application: app, vm: vm, adminMode: adminMode,
                    isPresented: Binding(
                        get: { selected != nil },
                        set: { if !$0 { selected = nil } }
                    )
                )
                .iPadSheet(.large)
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
                VStack(spacing: 12) {
                    filterChips
                    if vm.filteredRows.isEmpty {
                        Text(LocalizedStringKey("hp.apps.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVGrid(columns: SSAdaptiveColumns.cards, spacing: 10) {
                            ForEach(vm.filteredRows) { app in
                                rowCard(app)
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

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(ApplicationsViewModel.StatusFilter.allCases) { f in
                let selected = vm.statusFilter == f
                Button { vm.statusFilter = f } label: {
                    Text(LocalizedStringKey(f.labelKey))
                        .font(.ssCaption.weight(.semibold))
                        .foregroundStyle(selected ? Color.ssCream : Color.ssGreen)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selected ? Color.ssGreen : Color.ssPale)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func rowCard(_ app: Application) -> some View {
        Button { selected = app } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(app.displayName)
                        .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                    Spacer()
                    statusBadge(app.status ?? "")
                }
                if let email = app.email {
                    Text(email).font(.ssCaption).foregroundStyle(Color.ssGrey)
                }
                if let committee = app.assignedCommitteeName {
                    Label(committee, systemImage: "building.2")
                        .font(.ssTiny).foregroundStyle(Color.ssCharcoal)
                }
                if let date = MemberFieldMaps.displayDate(app.createdAt) {
                    Label(date, systemImage: "calendar")
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
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "PendingTriage":       return (.ssGrey,  "hp.apps.status_pending_triage")
            case "AssignedToCommittee": return (.ssGold,  "hp.apps.status_assigned")
            case "InterviewRequested":  return (.ssGold,  "hp.apps.status_interview")
            case "Accepted":            return (.ssGreen, "hp.apps.status_accepted")
            case "Rejected":            return (.red,     "hp.apps.status_rejected")
            default:                    return (.ssGrey,  "")
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

// MARK: - Detail sheet (accept / reject / interview)

private struct ApplicationDetailSheet: View {
    let application: Application
    @ObservedObject var vm: ApplicationsViewModel
    let adminMode: Bool
    @Binding var isPresented: Bool

    @State private var note: String = ""
    @State private var rejectReason: String = ""
    @State private var showingReject: Bool = false
    @State private var pickingCommittee: Bool = false
    @State private var selectedCommitteeId: String = ""
    @State private var cvViewerURL: IdentifiableURL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    section("hp.apps.section_applicant", rows: [
                        ("apply.s1.name_ar", application.nameAr ?? application.fullName ?? "—"),
                        ("apply.s1.name_en", application.nameEn ?? "—"),
                        ("apply.s1.preferred_name", application.preferredName ?? "—"),
                        ("apply.s1.national_id", application.nationalId ?? "—"),
                    ])
                    section("hp.apps.section_contact", rows: [
                        ("apply.s1.email", application.email ?? "—"),
                        ("apply.s1.phone", formatPhone(code: application.phoneCountryCode, num: application.phone)),
                        ("apply.s1.whatsapp", formatPhone(code: application.whatsappCountryCode, num: application.whatsapp)),
                    ])
                    section("hp.apps.section_study", rows: [
                        ("apply.s4.university", universityLabel),
                        ("apply.s4.study_level", MemberFieldMaps.studyLevelLabel(application.studyLevel) ?? "—"),
                        ("apply.s4.degree_field", application.degreeField ?? "—"),
                    ])
                    if let cv = application.cvUrl, !cv.isEmpty,
                       let cvURL = URL(string: cv) {
                        Button { cvViewerURL = IdentifiableURL(cvURL) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                Text(LocalizedStringKey("hp.apps.cv_link"))
                            }
                            .font(.ssCaption.weight(.semibold))
                            .foregroundStyle(Color.ssGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    if let about = application.aboutSelf, !about.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("hp.apps.section_motivation"))
                                .font(.ssH2).foregroundStyle(Color.ssGreen)
                            Text(about).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                        }
                    }
                    if let interests = application.interests, !interests.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("hp.apps.section_interests"))
                                .font(.ssH2).foregroundStyle(Color.ssGreen)
                            Text(interests.map { id in
                                vm.committees.first { $0.id == id }?.name ?? id
                            }.joined(separator: " · "))
                                .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                        }
                    }

                    GoldRule(width: 32)

                    actions
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.apps.sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
            .sheet(isPresented: $showingReject) {
                rejectSheet.iPadSheet(.medium)
            }
            .sheet(isPresented: $pickingCommittee) {
                committeePicker.iPadSheet(.medium)
            }
            .sheet(item: $cvViewerURL) { wrapped in
                RemoteFileViewer(
                    url: wrapped.url,
                    suggestedName: "\(application.displayName).pdf"
                )
                .iPadSheet(.xlarge)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(application.displayName)
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            if let committee = application.assignedCommitteeName {
                Text(committee).font(.ssCaption).foregroundStyle(Color.ssGrey)
            }
            GoldRule(width: 32)
        }
    }

    @ViewBuilder
    private var actions: some View {
        let canDecide = application.status == "AssignedToCommittee"
                     || application.status == "InterviewRequested"
        let pendingTriage = application.status == "PendingTriage"

        VStack(spacing: 10) {
            if adminMode && pendingTriage {
                Button { pickingCommittee = true } label: {
                    actionLabel("ap.apps.assign_committee_btn", systemImage: "arrow.right.circle", color: Color.ssGreen)
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)
            }
            if canDecide {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("hp.apps.note_label"))
                        .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    TextEditor(text: $note)
                        .frame(minHeight: 60)
                        .padding(6)
                        .background(Color.ssPale)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scrollContentBackground(.hidden)
                }
                Button {
                    Task {
                        let ok = await vm.accept(application, note: note)
                        if ok { isPresented = false }
                    }
                } label: {
                    actionLabel("hp.apps.accept_btn", systemImage: "checkmark.circle", color: Color.ssGreen)
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)

                Button {
                    Task {
                        let ok = await vm.requestInterview(application, note: note)
                        if ok { isPresented = false }
                    }
                } label: {
                    actionLabel("hp.apps.interview_btn", systemImage: "video", color: Color.ssGold)
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)
            }
            if application.status != "Accepted" && application.status != "Rejected" {
                Button { showingReject = true } label: {
                    actionLabel("hp.apps.reject_btn", systemImage: "xmark.circle", color: .red)
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)
            }
        }
    }

    private func actionLabel(_ key: String, systemImage: String, color: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(LocalizedStringKey(key)).font(.ssBodyBold)
        }
        .foregroundStyle(Color.ssCream)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var rejectSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey("hp.apps.reason_label"))
                    .font(.ssCaption).foregroundStyle(Color.ssGrey)
                TextEditor(text: $rejectReason)
                    .frame(minHeight: 100)
                    .padding(6)
                    .background(Color.ssPale)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .scrollContentBackground(.hidden)
                Button {
                    Task {
                        // Keep the reject sheet (and its typed reason)
                        // open on failure so the user can retry.
                        let ok = await vm.reject(application, reason: rejectReason)
                        if ok {
                            showingReject = false
                            isPresented = false
                        }
                    }
                } label: {
                    actionLabel("hp.apps.reject_btn", systemImage: "xmark.circle", color: .red)
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)
                Spacer()
            }
            .padding(20)
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.apps.reject_btn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { showingReject = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
    }

    private var committeePicker: some View {
        NavigationStack {
            List(vm.committees) { c in
                Button {
                    Task {
                        await vm.assignCommittee(application, committeeId: c.id)
                        pickingCommittee = false
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Text(c.name).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Color.ssGrey).font(.caption)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.ssCream)
            .navigationTitle(LocalizedStringKey("ap.apps.assign_committee_btn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { pickingCommittee = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
        }
    }

    private var universityLabel: String {
        if let other = application.universityOther, !other.isEmpty {
            return other
        }
        return MemberFieldMaps.universityLabel(application.university) ?? "—"
    }

    private func formatPhone(code: String?, num: String?) -> String {
        let n = num ?? ""
        if n.isEmpty { return "—" }
        if let c = code, !c.isEmpty { return "\(c) \(n)" }
        return n
    }

    private func section(_ titleKey: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            VStack(spacing: 4) {
                ForEach(0..<rows.count, id: \.self) { i in
                    HStack(alignment: .top) {
                        Text(LocalizedStringKey(rows[i].0))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .frame(width: 120, alignment: .leading)
                        Text(rows[i].1)
                            .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(10)
            .background(Color.ssPale)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
