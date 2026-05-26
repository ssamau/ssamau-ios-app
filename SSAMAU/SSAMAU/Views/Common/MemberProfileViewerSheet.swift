import SwiftUI

/// Read-only member profile sheet for heads + admins. Tap a member in
/// HeadMembersView / AccountsView to open this sheet with the full
/// profile rendered as labeled sections, plus the member's hours
/// summary and recent assignments fetched in parallel.
///
/// Strictly read-only: edits go through the web admin OR the existing
/// invite/PIN flow. This sheet is for triage + reference, not editing.
struct MemberProfileViewerSheet: View {
    let row: MemberAccountRow
    @Binding var isPresented: Bool

    @StateObject private var vm = MemberProfileViewerViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    activitySummary

                    section(titleKey: "ap.apps.section_applicant", rows: [
                        ("apply.s1.preferred_name", row.memberPreferredName ?? "—"),
                        ("apply.s1.name_ar", row.memberFullName ?? "—"),
                    ])
                    section(titleKey: "ap.apps.section_contact", rows: [
                        ("apply.s1.email", row.authEmail ?? "—"),
                    ])
                    section(titleKey: "mp.profile.section_account", rows: [
                        ("mp.profile.ro_committee", row.memberCommitteeName ?? "—"),
                        ("mp.profile.ro_role", MemberFieldMaps.roleLabel(row.memberClubRole) ?? "—"),
                        ("mp.profile.ro_full_name", row.memberFullName ?? row.displayName),
                        ("hp.members.viewer_member_id", row.memberId ?? "—"),
                    ])
                    if let username = row.username {
                        section(titleKey: "hp.members.viewer_account_section", rows: [
                            ("hp.members.viewer_username", username),
                            ("ap.advisors.field_role", row.accessLevel?.capitalized ?? "—"),
                            ("hp.members.viewer_last_login",
                                MemberFieldMaps.displayDate(row.lastLoginAt) ?? "—"),
                            ("hp.members.viewer_created_at",
                                MemberFieldMaps.displayDate(row.createdAt) ?? "—"),
                        ])
                    }

                    recentAssignments
                    recentHours
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.profile.viewer_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .task {
                if let id = row.memberId { await vm.load(memberId: id) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.ssGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayName)
                        .font(.ssH2).foregroundStyle(Color.ssGreen)
                    stateBadge(row.state)
                }
                Spacer()
            }
            GoldRule(width: 32)
        }
    }

    // MARK: - Activity summary (counts)

    @ViewBuilder
    private var activitySummary: some View {
        if row.memberId != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill").foregroundStyle(Color.ssGold)
                    Text(LocalizedStringKey("hp.members.viewer_activity_title"))
                        .font(.ssH2).foregroundStyle(Color.ssGreen)
                }
                if vm.isLoading {
                    ProgressView().tint(Color.ssGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        stat(value: String(format: "%.1f", vm.totalApprovedHours),
                             unit: "hp.members.viewer_unit_hours",
                             labelKey: "hp.members.viewer_stat_total_hours",
                             icon: "clock.fill")
                        stat(value: "\(vm.pendingHoursCount)",
                             unit: "hp.members.viewer_unit_rows",
                             labelKey: "hp.members.viewer_stat_pending_hours",
                             icon: "clock.badge.exclamationmark")
                        stat(value: "\(vm.assignments.count)",
                             unit: "hp.members.viewer_unit_total",
                             labelKey: "hp.members.viewer_stat_assignments",
                             icon: "checklist")
                        stat(value: "\(vm.upcomingAssignmentsCount)",
                             unit: "hp.members.viewer_unit_open",
                             labelKey: "hp.members.viewer_stat_upcoming",
                             icon: "calendar.badge.clock")
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
    }

    private func stat(value: String, unit: String, labelKey: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.body).foregroundStyle(Color.ssGold)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.ssH1).foregroundStyle(Color.ssGreen)
                Text(LocalizedStringKey(unit))
                    .font(.ssTiny).foregroundStyle(Color.ssGrey)
            }
            Text(LocalizedStringKey(labelKey))
                .font(.ssTiny).foregroundStyle(Color.ssGrey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssCream)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Recent assignments

    @ViewBuilder
    private var recentAssignments: some View {
        let recent = Array(vm.assignments.prefix(5))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("hp.members.viewer_recent_assignments"))
                    .font(.ssH2).foregroundStyle(Color.ssGreen)
                VStack(spacing: 4) {
                    ForEach(recent) { a in
                        assignmentRow(a)
                    }
                }
                .padding(10)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func assignmentRow(_ a: AssignmentRow) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.projectName ?? "—")
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                if let role = a.assignedRoleName ?? a.roleName {
                    Text(role).font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
            }
            Spacer()
            attendanceBadge(a.attendanceStatus ?? "Pending")
        }
        .padding(.vertical, 4)
    }

    private func attendanceBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Attended": return (.ssGreen, "hp.opps.att_attended")
            case "Absent":   return (.red,     "hp.opps.att_absent")
            case "Excused":  return (.ssGold,  "hp.opps.att_excused")
            default:         return (.ssGrey,  "hp.opps.att_pending")
            }
        }()
        return Text(LocalizedStringKey(key))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Recent hours

    @ViewBuilder
    private var recentHours: some View {
        let recent = Array(vm.hours.prefix(5))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("hp.members.viewer_recent_hours"))
                    .font(.ssH2).foregroundStyle(Color.ssGreen)
                VStack(spacing: 4) {
                    ForEach(recent) { h in
                        hoursRow(h)
                    }
                }
                .padding(10)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func hoursRow(_ h: HoursAdminRow) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(h.displayTitle)
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                    .lineLimit(1)
                hoursStatusBadge(h.approvalStatus)
            }
            Spacer()
            Text(String(format: "%.1f h", h.totalHours))
                .font(.ssCaption.weight(.semibold))
                .foregroundStyle(Color.ssGold)
        }
        .padding(.vertical, 4)
    }

    private func hoursStatusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Draft":           return (.ssGrey,  "mp.hours.status_draft")
            case "PrimaryApproved": return (.ssGold,  "mp.hours.status_primary")
            case "FinalApproved":   return (.ssGreen, "mp.hours.status_final")
            case "Rejected":        return (.red,     "mp.hours.status_rejected")
            default:                return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Shared

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

    private func section(titleKey: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            VStack(spacing: 4) {
                ForEach(0..<rows.count, id: \.self) { i in
                    HStack(alignment: .top) {
                        Text(LocalizedStringKey(rows[i].0))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .frame(width: 140, alignment: .leading)
                        Text(rows[i].1)
                            .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(10)
            .background(Color.ssPale)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
