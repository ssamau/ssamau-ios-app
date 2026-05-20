import SwiftUI

/// Member-mode profile screen — spec §8.2.
/// First pass is read-only: header + stat cards + form fields rendered as
/// labels. Editing, photo upload, and CV upload land in a follow-up.
struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.profile"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color("Background"))
                .refreshable { await vm.load() }
                .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let member = vm.member {
            loaded(member)
        } else if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background"))
        } else if let error = vm.errorMessage {
            errorState(error)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loaded(_ member: Member) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(member)
                stats(member)
                section(title: "mp.profile.sec_personal") {
                    row("mp.profile.lbl_preferred_name", member.preferredName)
                    row("mp.profile.lbl_email", member.email)
                    row("mp.profile.lbl_phone", member.phone)
                    row("mp.profile.lbl_whatsapp", member.whatsapp)
                    row("mp.profile.lbl_dob", member.dateOfBirth)
                    row("mp.profile.lbl_address", member.addressMelbourne)
                    row("mp.profile.lbl_linkedin", member.linkedinUrl)
                }
                section(title: "mp.profile.sec_study") {
                    row("mp.profile.lbl_scholarship", member.scholarshipEntity)
                    row("mp.profile.lbl_study_level", member.studyLevel)
                    row("mp.profile.lbl_degree_field", member.degreeField)
                    row("mp.profile.lbl_university", member.university)
                }
                section(title: "mp.profile.sec_about") {
                    row("mp.profile.lbl_skills", member.skillsHobbies)
                    row("mp.profile.lbl_about", member.aboutSelf)
                }
                section(title: "mp.profile.section_account") {
                    row("mp.profile.ro_full_name", member.fullName)
                    row("mp.profile.ro_nid", member.nationalId)
                    row("mp.profile.ro_committee", member.committeeName)
                    row("mp.profile.ro_role", member.clubRole)
                }
                Text(LocalizedStringKey("mp.profile.ro_note"))
                    .font(.footnote)
                    .foregroundStyle(Color("InkMuted"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                signOutButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Header

    private func header(_ member: Member) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("BackgroundSoft"))
                    .frame(width: 96, height: 96)
                if let url = member.profilePhotoUrl, let parsed = URL(string: url) {
                    AsyncImage(url: parsed) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            avatarFallback(member)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    avatarFallback(member)
                }
            }
            Text(member.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color("Ink"))
            HStack(spacing: 8) {
                if let committee = member.committeeName {
                    chip(committee, color: Color("BrandGreen"))
                }
                if let role = member.clubRole {
                    chip(role, color: Color("BrandGold"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func avatarFallback(_ member: Member) -> some View {
        Text(String(member.displayName.prefix(1)).uppercased())
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(Color("BrandGreen"))
            .frame(width: 96, height: 96)
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Stats

    private func stats(_ member: Member) -> some View {
        HStack(spacing: 12) {
            statCard(
                value: String(format: "%.0f", member.totalHours),
                labelKey: "mp.profile.stat_hours_label"
            )
            statCard(
                value: member.status,
                labelKey: "mp.profile.stat_status_label",
                valueColor: member.isActive ? Color("BrandGreen") : Color("InkMuted")
            )
        }
    }

    private func statCard(
        value: String,
        labelKey: LocalizedStringKey,
        valueColor: Color = Color("Ink")
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(valueColor)
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(Color("InkMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("BackgroundSoft"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sections + rows

    private func section<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("InkMuted"))
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                content()
            }
            .background(Color("BackgroundSoft"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func row(_ labelKey: LocalizedStringKey, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(labelKey)
                .font(.footnote)
                .foregroundStyle(Color("InkMuted"))
                .frame(width: 120, alignment: .leading)
            Text(value?.isEmpty == false
                 ? value!
                 : String(localized: "mp.profile.opt_unspecified"))
                .font(.footnote)
                .foregroundStyle(Color("Ink"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Divider().padding(.horizontal, 14), alignment: .bottom)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task { await session.signOut() }
        } label: {
            Text(LocalizedStringKey("common.logout"))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .padding(.top, 16)
    }

    // MARK: - Error state

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color("InkMuted"))
            Text(message)
                .font(.callout)
                .foregroundStyle(Color("Ink"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.load() }
            } label: {
                Text(LocalizedStringKey("common.retry"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }
}
