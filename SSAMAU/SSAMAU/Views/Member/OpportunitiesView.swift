import SwiftUI

/// Member-mode opportunities list — spec §8.3.
struct OpportunitiesView: View {
    @StateObject private var vm = OpportunitiesViewModel()
    @State private var presentingOpportunity: Opportunity?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.opportunities"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(item: $presentingOpportunity) { opp in
                    PickRoleSheet(
                        opportunity: opp,
                        viewModel: vm,
                        isPresented: Binding(
                            get: { presentingOpportunity != nil },
                            set: { if !$0 { presentingOpportunity = nil } }
                        )
                    )
                    .iPadSheet(.medium)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.opportunities.isEmpty, vm.isLoading {
            ProgressView()
                .tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let error = vm.errorMessage, vm.opportunities.isEmpty {
            errorState(error)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchAndFilter
                if vm.filteredOpportunities.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.filteredOpportunities) { opp in
                            row(opp)
                        }
                    }
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var searchAndFilter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.ssGrey)
                TextField(
                    LocalizedStringKey("mp.opps.search_placeholder"),
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

            HStack(spacing: 8) {
                statusChip(.openOnly, label: "mp.opps.filter_open")
                statusChip(.all, label: "mp.opps.filter_all")
                Spacer()
            }
        }
    }

    private func statusChip(_ filter: OpportunitiesViewModel.StatusFilter,
                            label: LocalizedStringKey) -> some View {
        let selected = vm.statusFilter == filter
        return Button {
            vm.statusFilter = filter
        } label: {
            Text(label)
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

    private func row(_ opp: Opportunity) -> some View {
        let alreadyExpressed = vm.expressedOpportunityIds.contains(opp.id)
        return Button {
            presentingOpportunity = opp
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opp.projectName ?? opp.id)
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssGreen)
                            .multilineTextAlignment(.leading)
                        if let committee = opp.owningCommitteeName {
                            Text(committee)
                                .font(.ssCaption)
                                .foregroundStyle(Color.ssGrey)
                        }
                    }
                    Spacer()
                    if alreadyExpressed {
                        Label(LocalizedStringKey("mp.opps.expressed_chip"),
                              systemImage: "checkmark.circle.fill")
                            .font(.ssCaption.weight(.semibold))
                            .foregroundStyle(Color.ssGreen)
                    } else {
                        statusBadge(opp.status)
                    }
                }
                HStack(spacing: 12) {
                    if let date = MemberFieldMaps.displayDate(opp.eventDate) {
                        Label(date, systemImage: "calendar")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                    if opp.totalNeeded > 0 {
                        Label("\(opp.totalTaken)/\(opp.totalNeeded)",
                              systemImage: "person.2")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                }
                if !opp.roles.isEmpty {
                    Text(opp.roles.map(\.roleName).joined(separator: " · "))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssCharcoal)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssPale)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!opp.isOpenForInterest)
        .opacity(opp.isOpenForInterest ? 1 : 0.65)
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Open":       return (.ssGreen, "mp.opps.status_open")
            case "NeedsHelp":  return (.ssGold, "mp.opps.status_needs_help")
            case "Filled":     return (.ssGrey, "mp.opps.status_filled")
            case "Cancelled":  return (.red, "mp.opps.status_cancelled")
            case "Done":       return (.ssGrey, "mp.opps.status_done")
            default:           return (.ssGrey, "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.opps.empty"))
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(message)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.load() }
            } label: {
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
