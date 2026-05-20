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
    @State private var showWithdrawConfirm: Bool = false

    private enum SelectedRole: Hashable {
        case any
        case role(Int64)

        var roleId: Int64? {
            if case .role(let id) = self { return id }
            return nil
        }
    }

    private var existingInterest: InterestRequest? {
        viewModel.existingInterest(for: opportunity)
    }

    private var hasExistingInterest: Bool { existingInterest != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if hasExistingInterest {
                        existingBanner
                    }
                    rolesList
                    commentField
                    submit
                    if hasExistingInterest {
                        withdrawButton
                    }
                }
                .padding(20)
                .padding(.bottom, 80) // room for toast overlay
            }
            .background(Color.ssCream.ignoresSafeArea())
            .ssToast(Binding(
                get: { viewModel.toast },
                set: { viewModel.toast = $0 }
            ))
            .navigationTitle(LocalizedStringKey(
                hasExistingInterest
                ? "mp.opps.update_interest_title"
                : "mp.opps.pick_role_title"
            ))
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
            .onAppear {
                // Pre-select the role the member previously chose so
                // "submitting" with no changes is a true no-op visually.
                if let existing = existingInterest {
                    if let r = existing.roleId {
                        selectedRoleId = .role(r)
                    } else {
                        selectedRoleId = .any
                    }
                    comment = existing.comment ?? ""
                }
            }
            .confirmationDialog(
                LocalizedStringKey("mp.opps.withdraw_confirm"),
                isPresented: $showWithdrawConfirm,
                titleVisibility: .visible
            ) {
                Button(LocalizedStringKey("mp.opps.withdraw_btn"),
                       role: .destructive) {
                    Task {
                        isSubmitting = true
                        let ok = await viewModel.withdrawInterest(opportunity: opportunity)
                        isSubmitting = false
                        if ok { isPresented = false }
                    }
                }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
            }
        }
    }

    private var existingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.ssGreen)
            Text(LocalizedStringKey("mp.opps.already_expressed_banner"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssCharcoal)
            Spacer()
        }
        .padding(12)
        .background(Color.ssGreen.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ssGreen.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var withdrawButton: some View {
        Button(role: .destructive) {
            showWithdrawConfirm = true
        } label: {
            HStack {
                Image(systemName: "xmark.circle")
                Text(LocalizedStringKey("mp.opps.withdraw_btn"))
                    .font(.ssBodyBold)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.red.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSubmitting)
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
        // Disabled when every role is already at capacity — server
        // would reject with err.business.role_full per the 2026-05-21
        // web change (interest.submit's null-branch now enforces caps
        // on multi-role opps).
        let isFull = opportunity.isFullCapacity
        return Button {
            if !isFull { selectedRoleId = .any }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.ssGreen : Color.ssGrey)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("mp.opps.any_role"))
                        .font(.ssBodyBold)
                        .foregroundStyle(Color.ssCharcoal)
                    if isFull {
                        Text(LocalizedStringKey("mp.opps.all_roles_full"))
                            .font(.ssCaption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .opacity(isFull ? 0.5 : 1)
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
                Text(LocalizedStringKey(
                    hasExistingInterest
                    ? "mp.opps.update_interest_btn"
                    : "mp.opps.confirm_interest"
                ))
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
