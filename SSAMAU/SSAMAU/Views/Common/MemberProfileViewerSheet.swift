import SwiftUI

/// Read-only member profile sheet for heads + admins. Tap a member in
/// HeadMembersView / AccountsView and this sheet opens with the full
/// profile rendered as labeled sections. Shows whatever fields users.list
/// already returned — no extra round-trip, no risk of 403 from
/// admin-only fields.
///
/// Intentionally read-only: edits to members go through the web admin
/// (or are surfaced via separate flows like invite/revoke). This sheet
/// is for triage + reference, not editing.
struct MemberProfileViewerSheet: View {
    let row: MemberAccountRow
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

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
