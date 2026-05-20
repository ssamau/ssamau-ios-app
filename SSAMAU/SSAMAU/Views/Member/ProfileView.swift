import SwiftUI

/// Member-mode profile screen — spec §8.2.
struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.profile"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color("Background"))
                .toolbar { toolbarButtons }
                .refreshable { if !vm.isEditing { await vm.load() } }
                .task { await vm.load() }
                .overlay(alignment: .bottom) { toast }
        }
    }

    // MARK: - Content switcher

    @ViewBuilder
    private var content: some View {
        if let member = vm.draft ?? vm.member {
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        if vm.isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button(LocalizedStringKey("common.cancel")) {
                    vm.cancelEditing()
                }
                .disabled(vm.isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.save() }
                } label: {
                    if vm.isSaving {
                        ProgressView()
                    } else {
                        Text(LocalizedStringKey("common.save"))
                            .fontWeight(.semibold)
                    }
                }
                .disabled(vm.isSaving)
            }
        } else if vm.member != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LocalizedStringKey("common.edit")) {
                    vm.startEditing()
                }
            }
        }
    }

    // MARK: - Loaded body

    private func loaded(_ member: Member) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(member)
                stats(member)

                section("mp.profile.sec_personal") {
                    if vm.isEditing {
                        editableRow("mp.profile.lbl_preferred_name",
                                    binding: $vm.draft.unwrap(or: member).preferredName)
                        editableRow("mp.profile.lbl_email",
                                    binding: $vm.draft.unwrap(or: member).email,
                                    keyboard: .emailAddress, autocap: .never)
                        editableRow("mp.profile.lbl_phone",
                                    binding: $vm.draft.unwrap(or: member).phone,
                                    keyboard: .phonePad)
                        editableRow("mp.profile.lbl_whatsapp",
                                    binding: $vm.draft.unwrap(or: member).whatsapp,
                                    keyboard: .phonePad)
                        dobEditableRow(member)
                        editableRow("mp.profile.lbl_address",
                                    binding: $vm.draft.unwrap(or: member).addressMelbourne)
                        editableRow("mp.profile.lbl_linkedin",
                                    binding: $vm.draft.unwrap(or: member).linkedinUrl,
                                    keyboard: .URL, autocap: .never)
                    } else {
                        readRow("mp.profile.lbl_preferred_name", member.preferredName)
                        readRow("mp.profile.lbl_email", member.email)
                        readRow("mp.profile.lbl_phone", member.phone)
                        readRow("mp.profile.lbl_whatsapp", member.whatsapp)
                        readRow("mp.profile.lbl_dob", MemberFieldMaps.displayDate(member.dateOfBirth))
                        readRow("mp.profile.lbl_address", member.addressMelbourne)
                        readRow("mp.profile.lbl_linkedin", member.linkedinUrl)
                    }
                }

                section("mp.profile.sec_study") {
                    if vm.isEditing {
                        pickerRow("mp.profile.lbl_scholarship",
                                  binding: $vm.draft.unwrap(or: member).scholarshipEntity,
                                  options: MemberFieldMaps.scholarshipOpts)
                        pickerRow("mp.profile.lbl_study_level",
                                  binding: $vm.draft.unwrap(or: member).studyLevel,
                                  options: MemberFieldMaps.studyLevelOpts)
                        editableRow("mp.profile.lbl_degree_field",
                                    binding: $vm.draft.unwrap(or: member).degreeField)
                        pickerRow("mp.profile.lbl_university",
                                  binding: $vm.draft.unwrap(or: member).university,
                                  options: MemberFieldMaps.universityOpts)
                    } else {
                        readRow("mp.profile.lbl_scholarship",
                                MemberFieldMaps.scholarshipLabel(member.scholarshipEntity))
                        readRow("mp.profile.lbl_study_level",
                                MemberFieldMaps.studyLevelLabel(member.studyLevel))
                        readRow("mp.profile.lbl_degree_field", member.degreeField)
                        readRow("mp.profile.lbl_university",
                                MemberFieldMaps.universityLabel(member.university))
                    }
                }

                section("mp.profile.sec_about") {
                    if vm.isEditing {
                        editableRow("mp.profile.lbl_skills",
                                    binding: $vm.draft.unwrap(or: member).skillsHobbies,
                                    axis: .vertical)
                        editableRow("mp.profile.lbl_about",
                                    binding: $vm.draft.unwrap(or: member).aboutSelf,
                                    axis: .vertical)
                    } else {
                        readRow("mp.profile.lbl_skills", member.skillsHobbies)
                        readRow("mp.profile.lbl_about", member.aboutSelf)
                    }
                }

                section("mp.profile.section_account") {
                    readRow("mp.profile.ro_full_name", member.fullName ?? member.displayName)
                    readRow("mp.profile.ro_nid", member.nationalId)
                    readRow("mp.profile.ro_committee", member.committeeName)
                    readRow("mp.profile.ro_role", MemberFieldMaps.roleLabel(member.clubRole))
                }

                Text(LocalizedStringKey("mp.profile.ro_note"))
                    .font(.footnote)
                    .foregroundStyle(Color("InkMuted"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !vm.isEditing {
                    languageButton
                    signOutButton
                }
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
                    chip(MemberFieldMaps.roleLabel(role) ?? role,
                         color: Color("BrandGold"))
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
            statCard(value: String(format: "%.0f", member.totalHours),
                     labelKey: "mp.profile.stat_hours_label")
            statCard(value: MemberFieldMaps.statusLabel(member.status) ?? "—",
                     labelKey: "mp.profile.stat_status_label",
                     valueColor: member.isActive ? Color("BrandGreen") : Color("InkMuted"))
        }
    }

    private func statCard(value: String,
                          labelKey: LocalizedStringKey,
                          valueColor: Color = Color("Ink")) -> some View {
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

    // MARK: - Section + row building blocks

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("InkMuted"))
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color("BackgroundSoft"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func readRow(_ labelKey: LocalizedStringKey, _ value: String?) -> some View {
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

    private func editableRow(
        _ labelKey: LocalizedStringKey,
        binding: Binding<String?>,
        keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .sentences,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(Color("InkMuted"))
            TextField(
                String(localized: "mp.profile.opt_unspecified"),
                text: binding.orEmpty,
                axis: axis
            )
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap)
            .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
            .font(.footnote)
            .foregroundStyle(Color("Ink"))
            .lineLimit(axis == .vertical ? 5 : 1, reservesSpace: axis == .vertical)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Divider().padding(.horizontal, 14), alignment: .bottom)
    }

    private func pickerRow(
        _ labelKey: LocalizedStringKey,
        binding: Binding<String?>,
        options: [MemberFieldMaps.Option]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(Color("InkMuted"))
            Menu {
                Button(String(localized: "mp.profile.opt_unspecified")) { binding.wrappedValue = nil }
                ForEach(options, id: \.value) { opt in
                    Button(MemberFieldMaps.label(for: opt.value, in: options) ?? opt.value) {
                        binding.wrappedValue = opt.value
                    }
                }
            } label: {
                HStack {
                    Text(MemberFieldMaps.label(for: binding.wrappedValue, in: options)
                         ?? String(localized: "mp.profile.opt_unspecified"))
                        .font(.footnote)
                        .foregroundStyle(Color("Ink"))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color("InkMuted"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Divider().padding(.horizontal, 14), alignment: .bottom)
    }

    private func dobEditableRow(_ member: Member) -> some View {
        let parsed = MemberFieldMaps.parseServerDate(vm.draft?.dateOfBirth ?? member.dateOfBirth)
        let dateBinding = Binding<Date>(
            get: { parsed ?? Date() },
            set: { vm.draft?.dateOfBirth = MemberFieldMaps.serverDateString($0) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.profile.lbl_dob"))
                .font(.caption)
                .foregroundStyle(Color("InkMuted"))
            DatePicker("", selection: dateBinding,
                       in: ...Date(),
                       displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Divider().padding(.horizontal, 14), alignment: .bottom)
    }

    // MARK: - Language

    private var languageButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(LocalizedStringKey("lang.toggle_title"))
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.footnote)
                    .foregroundStyle(Color("InkMuted"))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.bordered)
        .tint(Color("BrandGreen"))
        .padding(.top, 16)
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

    // MARK: - Toast (success / save error)

    @ViewBuilder
    private var toast: some View {
        if let msg = vm.toastMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("BrandGreen"))
                .clipShape(Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    vm.toastMessage = nil
                }
        }
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

// MARK: - Binding helpers

private extension Binding where Value == String? {
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

private extension Binding {
    /// Unwraps an optional binding by mirroring writes to the wrapped value
    /// when present and ignoring them when nil. Returns a binding into the
    /// passed `fallback` when the optional is nil — used only as a transient
    /// proxy while the draft is non-nil (which is the invariant during edit).
    func unwrap<Wrapped>(or fallback: Wrapped) -> Binding<Wrapped>
    where Value == Optional<Wrapped> {
        Binding<Wrapped>(
            get: { (wrappedValue as Wrapped?) ?? fallback },
            set: { wrappedValue = $0 as Wrapped }
        )
    }
}
