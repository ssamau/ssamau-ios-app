import SwiftUI

/// Head-mode opportunities view — spec §9.4.
///
/// Server scopes `opportunities.list` to the caller (heads see their
/// own committee). Each row opens an assign sheet showing per-role
/// candidates (members who expressed interest) and current assignees
/// with attendance controls.
struct HeadOpportunitiesView: View {
    @StateObject private var vm = HeadOpportunitiesViewModel()
    @State private var presentingOpportunity: Opportunity?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("hp.tabs.opportunities"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(item: $presentingOpportunity) { opp in
                    AssignSheet(opportunity: opp, vm: vm) {
                        presentingOpportunity = nil
                    }
                    .iPadSheet(.large)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.opportunities.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage, vm.opportunities.isEmpty {
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
                if vm.filteredOpportunities.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.filteredOpportunities) { opp in
                            rowCard(opp)
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
            Image(systemName: "magnifyingglass").foregroundStyle(Color.ssGrey)
            TextField(LocalizedStringKey("hp.opps.search_placeholder"),
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

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HeadOpportunitiesViewModel.StatusFilter.allCases) { f in
                    chip(f)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(_ filter: HeadOpportunitiesViewModel.StatusFilter) -> some View {
        let selected = vm.statusFilter == filter
        return Button { vm.statusFilter = filter } label: {
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

    private func rowCard(_ opp: Opportunity) -> some View {
        Button { presentingOpportunity = opp } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opp.projectName ?? opp.id)
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssGreen)
                            .multilineTextAlignment(.leading)
                        if let c = opp.owningCommitteeName {
                            Text(c).font(.ssCaption).foregroundStyle(Color.ssGrey)
                        }
                    }
                    Spacer()
                    statusBadge(opp.status)
                }
                HStack(spacing: 12) {
                    if let date = MemberFieldMaps.displayDate(opp.eventDate) {
                        Label(date, systemImage: "calendar")
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                    if opp.totalNeeded > 0 {
                        Label("\(opp.totalTaken)/\(opp.totalNeeded)",
                              systemImage: "person.2")
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                }
                if !opp.roles.isEmpty {
                    Text(opp.roles.map { "\($0.roleName) (\($0.taken)/\($0.headcountNeeded))" }
                            .joined(separator: " · "))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssCharcoal)
                        .lineLimit(2)
                }
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

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Open":      return (.ssGreen, "mp.opps.status_open")
            case "NeedsHelp": return (.ssGold,  "mp.opps.status_needs_help")
            case "Filled":    return (.ssGrey,  "mp.opps.status_filled")
            case "Cancelled": return (.red,     "mp.opps.status_cancelled")
            case "Done":      return (.ssGrey,  "mp.opps.status_done")
            default:          return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36)).foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("hp.opps.empty"))
                .font(.ssBody).foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

// MARK: - AssignSheet

private struct AssignSheet: View {
    let opportunity: Opportunity
    @ObservedObject var vm: HeadOpportunitiesViewModel
    let onClose: () -> Void

    @State private var selectedRoleId: Int64?    // nil → any-role
    @State private var attendanceTarget: AssignmentRow?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !opportunity.roles.isEmpty {
                        roleChips
                    }
                    assigneesSection
                    candidatesSection
                }
                .padding(20)
                .padding(.bottom, 60)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.opps.assign_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { onClose() }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .task { await vm.loadDetail(for: opportunity) }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
            .sheet(item: $attendanceTarget) { row in
                AttendanceSheet(
                    assignment: row,
                    opportunity: opportunity,
                    vm: vm,
                    isPresented: Binding(
                        get: { attendanceTarget != nil },
                        set: { if !$0 { attendanceTarget = nil } }
                    )
                )
                .iPadSheet(.medium)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(opportunity.projectName ?? opportunity.id)
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            if let c = opportunity.owningCommitteeName {
                Text(c).font(.ssCaption).foregroundStyle(Color.ssGrey)
            }
            if let date = MemberFieldMaps.displayDate(opportunity.eventDate) {
                Label(date, systemImage: "calendar")
                    .font(.ssCaption).foregroundStyle(Color.ssGrey)
            }
            GoldRule(width: 32)
        }
    }

    private var roleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                roleChip(id: nil, label: NSLocalizedString("hp.opps.role_any", comment: ""))
                ForEach(opportunity.roles) { role in
                    roleChip(
                        id: role.id,
                        label: "\(role.roleName) (\(role.taken)/\(role.headcountNeeded))"
                    )
                }
            }
        }
    }

    private func roleChip(id: Int64?, label: String) -> some View {
        let selected = selectedRoleId == id
        return Button { selectedRoleId = id } label: {
            Text(label)
                .font(.ssCaption.weight(.semibold))
                .foregroundStyle(selected ? Color.ssCream : Color.ssGreen)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.ssGreen : Color.ssPale)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var assignees: [AssignmentRow] {
        (vm.assignments[opportunity.id] ?? [])
            .filter { selectedRoleId == nil || $0.roleId == selectedRoleId }
    }

    private var assigneesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("hp.opps.section_assigned"))
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            if assignees.isEmpty {
                Text(LocalizedStringKey("hp.opps.assigned_none"))
                    .font(.ssCaption).foregroundStyle(Color.ssGrey)
            } else {
                ForEach(assignees) { a in
                    assigneeCard(a)
                }
            }
        }
    }

    private func assigneeCard(_ a: AssignmentRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.displayName)
                        .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                    if let role = a.assignedRoleName ?? a.roleName {
                        Text(role).font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                }
                Spacer()
                attendanceBadge(a.attendanceStatus)
            }
            HStack(spacing: 8) {
                Button {
                    attendanceTarget = a
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.rectangle")
                        Text(LocalizedStringKey("hp.opps.mark_attendance"))
                    }
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.ssCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Task { await vm.removeAssignment(a, opportunity: opportunity) }
                } label: {
                    HStack(spacing: 6) {
                        if vm.inFlightAssignmentId == a.id {
                            ProgressView().tint(.red)
                        } else {
                            Image(systemName: "xmark")
                        }
                        Text(LocalizedStringKey("hp.opps.remove_assignment"))
                    }
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.ssCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightAssignmentId != nil)
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func attendanceBadge(_ status: String?) -> some View {
        let (color, label): (Color, String) = {
            switch status ?? "" {
            case "Attended": return (.ssGreen, NSLocalizedString("hp.opps.att_attended", comment: ""))
            case "Absent":   return (.red,     NSLocalizedString("hp.opps.att_absent", comment: ""))
            case "Excused":  return (.ssGold,  NSLocalizedString("hp.opps.att_excused", comment: ""))
            default:         return (.ssGrey,  NSLocalizedString("hp.opps.att_pending", comment: ""))
            }
        }()
        return Text(label)
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var assignedMemberIds: Set<String> {
        Set((vm.assignments[opportunity.id] ?? []).compactMap(\.memberId))
    }

    private var candidates: [InterestRow] {
        let assigned = assignedMemberIds
        return (vm.interestRows[opportunity.id] ?? [])
            .filter { !assigned.contains($0.memberId) }
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("hp.opps.section_interested"))
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            if candidates.isEmpty {
                Text(LocalizedStringKey("hp.opps.interested_none"))
                    .font(.ssCaption).foregroundStyle(Color.ssGrey)
            } else {
                ForEach(candidates) { c in
                    candidateCard(c)
                }
            }
        }
    }

    private func candidateCard(_ c: InterestRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.displayName)
                        .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                    if let picked = c.pickedRoleName {
                        Text(picked).font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                    } else if c.isAnyRole {
                        Text(LocalizedStringKey("hp.opps.any_role_chip"))
                            .font(.ssTiny.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.ssGold)
                            .clipShape(Capsule())
                    }
                    if let mc = c.memberCommitteeName {
                        Text(mc).font(.ssTiny).foregroundStyle(Color.ssGrey)
                    }
                }
                Spacer()
                Button {
                    let role = opportunity.roles.first { $0.id == selectedRoleId }
                    Task { await vm.assign(member: c, to: role, opportunity: opportunity) }
                } label: {
                    HStack(spacing: 6) {
                        if vm.inFlightMemberId == c.memberId {
                            ProgressView().tint(Color.ssCream)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text(LocalizedStringKey("hp.opps.assign_btn"))
                    }
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.ssGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightMemberId != nil)
            }
            if let comment = c.comment, !comment.isEmpty {
                Text(comment)
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ssCream)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AttendanceSheet (per-assignment status + optional hours override)

private struct AttendanceSheet: View {
    let assignment: AssignmentRow
    let opportunity: Opportunity
    @ObservedObject var vm: HeadOpportunitiesViewModel
    @Binding var isPresented: Bool

    @State private var status: String = "Attended"
    @State private var hoursOverrideText: String = ""
    @State private var includeHoursOverride: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(assignment.displayName)
                        .font(.ssH2).foregroundStyle(Color.ssGreen)
                    if let role = assignment.assignedRoleName ?? assignment.roleName {
                        Text(role).font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                    GoldRule(width: 32)

                    Picker(selection: $status) {
                        Text(LocalizedStringKey("hp.opps.att_attended")).tag("Attended")
                        Text(LocalizedStringKey("hp.opps.att_absent")).tag("Absent")
                        Text(LocalizedStringKey("hp.opps.att_excused")).tag("Excused")
                        Text(LocalizedStringKey("hp.opps.att_pending")).tag("Pending")
                    } label: {
                        Text(LocalizedStringKey("hp.opps.att_status_label"))
                    }
                    .pickerStyle(.segmented)

                    if status == "Attended" {
                        Toggle(isOn: $includeHoursOverride) {
                            Text(LocalizedStringKey("hp.opps.att_hours_toggle"))
                                .font(.ssBody)
                                .foregroundStyle(Color.ssCharcoal)
                        }
                        .tint(Color.ssGreen)

                        if includeHoursOverride {
                            HStack {
                                Text(LocalizedStringKey("hp.opps.att_hours_label"))
                                    .font(.ssCaption)
                                    .foregroundStyle(Color.ssGrey)
                                TextField("0.0", text: $hoursOverrideText)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                                    .background(Color.ssPale)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.ssLight, lineWidth: 1)
                                    )
                            }
                            Text(LocalizedStringKey("hp.opps.att_hours_hint"))
                                .font(.ssTiny).foregroundStyle(Color.ssGrey)
                        }
                    }

                    Button {
                        Task {
                            let h: Double? = (includeHoursOverride && status == "Attended")
                                ? Double(hoursOverrideText) : nil
                            let ok = await vm.markAttendance(
                                assignment, status: status,
                                hoursOverride: h, opportunity: opportunity
                            )
                            // Keep the sheet open on failure so the head
                            // doesn't lose their hours/status pick on a
                            // transient server error.
                            if ok { isPresented = false }
                        }
                    } label: {
                        HStack {
                            if vm.inFlightAssignmentId == assignment.id {
                                ProgressView().tint(Color.ssCream)
                            }
                            Text(LocalizedStringKey("hp.opps.att_save"))
                                .font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.ssGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlightAssignmentId != nil)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.opps.att_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
        .onAppear {
            status = assignment.attendanceStatus ?? "Attended"
        }
    }
}
