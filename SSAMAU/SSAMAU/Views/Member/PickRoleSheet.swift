import SwiftUI

/// Role-picker sheet for an opportunity. Member picks one of the
/// available roles (or "Any role"), optionally adds a comment, and
/// confirms. Submits via `interest.submit`. Spec §8.4.
struct PickRoleSheet: View {
    let opportunity: Opportunity
    let viewModel: OpportunitiesViewModel
    @Binding var isPresented: Bool

    @State private var selectedRoleId: SelectedRole = .any
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false

    private enum SelectedRole: Hashable {
        case any
        case role(Int64)

        var roleId: Int64? {
            if case .role(let id) = self { return id }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    rolesList
                    commentField
                    submit
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("mp.opps.pick_role_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) {
                        isPresented = false
                    }
                    .foregroundStyle(Color.ssGrey)
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(opportunity.projectName ?? opportunity.id)
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            if let committee = opportunity.owningCommitteeName {
                Text(committee)
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rolesList: some View {
        VStack(spacing: 0) {
            ForEach(opportunity.roles) { role in
                roleRow(role)
            }
            anyRoleRow
        }
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
    }

    private func roleRow(_ role: OpportunityRole) -> some View {
        let isSelected = selectedRoleId == .role(role.id)
        let isFull = role.isFull
        return Button {
            if !isFull { selectedRoleId = .role(role.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.ssGreen : Color.ssGrey)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.roleName)
                        .font(.ssBodyBold)
                        .foregroundStyle(Color.ssCharcoal)
                    HStack(spacing: 6) {
                        Text("\(role.remaining) / \(role.headcountNeeded)")
                            .font(.ssCaption)
                            .foregroundStyle(isFull ? .red : Color.ssGrey)
                        Text("·")
                            .foregroundStyle(Color.ssGrey)
                        Text(String(format: "%.0fh", role.estimatedHours))
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                Rectangle()
                    .fill(Color.ssLight.opacity(0.6))
                    .frame(height: 0.5)
                    .padding(.horizontal, 14),
                alignment: .bottom
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .opacity(isFull ? 0.5 : 1)
    }

    private var anyRoleRow: some View {
        let isSelected = selectedRoleId == .any
        return Button {
            selectedRoleId = .any
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.ssGreen : Color.ssGrey)
                    .font(.title3)
                Text(LocalizedStringKey("mp.opps.any_role"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.opps.comment_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            TextField(
                LocalizedStringKey("mp.opps.comment_placeholder"),
                text: $comment,
                axis: .vertical
            )
            .font(.ssBody)
            .foregroundStyle(Color.ssCharcoal)
            .lineLimit(3, reservesSpace: true)
            .padding(12)
            .background(Color.ssPale)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ssLight, lineWidth: 1)
            )
        }
    }

    private var submit: some View {
        Button {
            Task {
                isSubmitting = true
                let ok = await viewModel.expressInterest(
                    opportunity: opportunity,
                    roleId: selectedRoleId.roleId,
                    comment: comment
                )
                isSubmitting = false
                if ok { isPresented = false }
            }
        } label: {
            ZStack {
                Text(LocalizedStringKey("mp.opps.confirm_interest"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .opacity(isSubmitting ? 0 : 1)
                if isSubmitting {
                    ProgressView().tint(Color.ssCream)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.ssGreen)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSubmitting)
    }
}
