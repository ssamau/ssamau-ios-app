import SwiftUI

/// Member-mode profile screen — spec §8.2, styled per SSAM Brand Identity Guide.
struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.profile"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .toolbar { toolbarButtons }
                .refreshable { if !vm.isEditing { await vm.load() } }
                .task { await vm.load() }
                .overlay(alignment: .bottom) { toast }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let member = vm.draft ?? vm.member {
            loaded(member)
        } else if vm.isLoading {
            ProgressView()
                .tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let error = vm.errorMessage {
            errorState(error)
        } else {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        if vm.isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button(LocalizedStringKey("common.cancel")) {
                    vm.cancelEditing()
                }
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .disabled(vm.isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.save() }
                } label: {
                    if vm.isSaving {
                        ProgressView().tint(Color.ssGreen)
                    } else {
                        Text(LocalizedStringKey("common.save"))
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssGreen)
                    }
                }
                .disabled(vm.isSaving)
            }
        } else if vm.member != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LocalizedStringKey("common.edit")) {
                    vm.startEditing()
                }
                .font(.ssBody)
                .foregroundStyle(Color.ssGreen)
            }
        }
    }

    // MARK: - Loaded body

    private func loaded(_ member: Member) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                header(member)
                stats(member)

                section(latin: "Personal Info", arabic: "mp.profile.sec_personal") {
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

                section(latin: "Study & Sponsorship", arabic: "mp.profile.sec_study") {
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

                section(latin: "About You", arabic: "mp.profile.sec_about") {
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

                section(latin: "Account", arabic: "mp.profile.section_account") {
                    readRow("mp.profile.ro_full_name", member.fullName ?? member.displayName)
                    readRow("mp.profile.ro_nid", member.nationalId)
                    readRow("mp.profile.ro_committee", member.committeeName)
                    readRow("mp.profile.ro_role", MemberFieldMaps.roleLabel(member.clubRole))
                }

                Text(LocalizedStringKey("mp.profile.ro_note"))
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                if !vm.isEditing {
                    languageButton
                    signOutButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Header

    private func header(_ member: Member) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.ssPale)
                    .overlay(Circle().stroke(Color.ssGold, lineWidth: 1.5))
                    .frame(width: 100, height: 100)
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
                .font(.ssH1)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            GoldRule(width: 40)
            HStack(spacing: 8) {
                if let committee = member.committeeName {
                    chip(committee, fill: Color.ssGreen, text: Color.ssCream)
                }
                if let role = member.clubRole {
                    chip(MemberFieldMaps.roleLabel(role) ?? role,
                         fill: Color.ssGold, text: Color.ssCream)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func avatarFallback(_ member: Member) -> some View {
        Text(String(member.displayName.prefix(1)).uppercased())
            .font(.custom("Almarai-Bold", size: 42))
            .foregroundStyle(Color.ssGreen)
            .frame(width: 96, height: 96)
    }

    private func chip(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(fill)
            .clipShape(Capsule())
    }

    // MARK: - Stats

    private func stats(_ member: Member) -> some View {
        HStack(spacing: 12) {
            statCard(value: String(format: "%.0f", member.totalHours),
                     labelKey: "mp.profile.stat_hours_label")
            statCard(value: MemberFieldMaps.statusLabel(member.status) ?? "—",
                     labelKey: "mp.profile.stat_status_label",
                     valueColor: member.isActive ? Color.ssGreen : Color.ssGrey)
        }
    }

    private func statCard(value: String,
                          labelKey: LocalizedStringKey,
                          valueColor: Color = Color.ssCharcoal) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.ssDisplay)
                .foregroundStyle(valueColor)
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Section + rows

    /// Section header: Latin small-caps label above Arabic h2 — matches the
    /// "T H E   B O A R D / مجلس إدارة النادي" pattern from the brand guide.
    private func section<Content: View>(
        latin: String,
        arabic: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(latin)
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            Text(arabic)
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.ssPale)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func readRow(_ labelKey: LocalizedStringKey, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .frame(width: 120, alignment: .leading)
            Text(value?.isEmpty == false
                 ? value!
                 : String(localized: "mp.profile.opt_unspecified"))
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
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
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            TextField(
                String(localized: "mp.profile.opt_unspecified"),
                text: binding.orEmpty,
                axis: axis
            )
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap)
            .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
            .font(.ssBody)
            .foregroundStyle(Color.ssCharcoal)
            .lineLimit(axis == .vertical ? 5 : 1, reservesSpace: axis == .vertical)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
    }

    private func pickerRow(
        _ labelKey: LocalizedStringKey,
        binding: Binding<String?>,
        options: [MemberFieldMaps.Option]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
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
                        .font(.ssBody)
                        .foregroundStyle(Color.ssCharcoal)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.ssGrey)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
    }

    private func dobEditableRow(_ member: Member) -> some View {
        let parsed = MemberFieldMaps.parseServerDate(vm.draft?.dateOfBirth ?? member.dateOfBirth)
        let dateBinding = Binding<Date>(
            get: { parsed ?? Date() },
            set: { vm.draft?.dateOfBirth = MemberFieldMaps.serverDateString($0) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.profile.lbl_dob"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            DatePicker("", selection: dateBinding,
                       in: ...Date(),
                       displayedComponents: .date)
                .labelsHidden()
                .tint(Color.ssGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
    }

    // MARK: - Language + Sign out

    private var languageButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(LocalizedStringKey("lang.toggle_title"))
                    .font(.ssBody)
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
            }
            .foregroundStyle(Color.ssGreen)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 12)
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task { await session.signOut() }
        } label: {
            Text(LocalizedStringKey("common.logout"))
                .font(.ssBodyBold)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.ssPale)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.red.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toast: some View {
        if let msg = vm.toastMessage {
            Text(msg)
                .font(.ssCaption)
                .foregroundStyle(Color.ssCream)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.ssGreen)
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
        VStack(spacing: 14) {
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
    func unwrap<Wrapped>(or fallback: Wrapped) -> Binding<Wrapped>
    where Value == Optional<Wrapped> {
        Binding<Wrapped>(
            get: { (wrappedValue as Wrapped?) ?? fallback },
            set: { wrappedValue = $0 as Wrapped }
        )
    }
}
