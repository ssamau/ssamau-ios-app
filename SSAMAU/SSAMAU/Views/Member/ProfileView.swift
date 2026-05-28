import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Member-mode profile screen — spec §8.2, styled per SSAM Brand Identity Guide.
struct ProfileView: View {
    /// When this view is pushed inside another NavigationStack (e.g. the
    /// head's More tab), DON'T wrap content in our own NavigationStack —
    /// nesting them corrupts SwiftUI's navigationDestination registry on
    /// the outer stack (next push silently fails with "no matching
    /// navigationDestination" in the console).
    var nestedInNavStack: Bool = false

    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = ProfileViewModel()
    @State private var showSettingsFallback = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCVPicker = false
    @State private var showDeletePhotoConfirm = false
    @State private var showDeleteCVConfirm = false
    @State private var showSupportSheet = false

    var body: some View {
        if nestedInNavStack {
            decorated
        } else {
            NavigationStack { decorated }
        }
    }

    private var decorated: some View {
        content
            .navigationTitle(LocalizedStringKey("mp.tabs.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .toolbar { toolbarButtons }
            .refreshable { if !vm.isEditing { await vm.load() } }
            .task { await vm.load() }
            .ssToast($vm.toast)
            .alert(
                LocalizedStringKey("settings.cant_open.title"),
                isPresented: $showSettingsFallback
            ) {
                Button(LocalizedStringKey("common.ok")) {}
            } message: {
                Text(LocalizedStringKey("settings.cant_open.message"))
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

                if !vm.isEditing {
                    filesSection
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
                    supportButton
                    signOutButton
                    versionFooter
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    /// Version stamp at the very bottom of the profile screen. Tappable
    /// to copy build info to the clipboard — useful when triaging a
    /// support ticket the user just filed.
    private var versionFooter: some View {
        Button {
            UIPasteboard.general.string = AppInfo.displayVersion
            vm.toast = .info(ErrorLocalization.localize("common.copied"))
        } label: {
            Text(AppInfo.displayVersion)
                .font(.ssTiny)
                .foregroundStyle(Color.ssGrey)
                .padding(.top, 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("App version \(AppInfo.displayVersion)"))
    }

    // MARK: - Header

    private func header(_ member: Member) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.ssPale)
                    .overlay(Circle().stroke(Color.ssGold, lineWidth: 1.5))
                    .frame(width: 100, height: 100)
                if let url = vm.photoSignedURL {
                    AsyncImage(url: url) { phase in
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

    // MARK: - Files (photo + CV)

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Files")
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.profile.sec_files"))
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                photoRow
                cvRow
            }
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onChange(of: photoPickerItem) { newItem in
            handlePhotoSelection(newItem)
        }
        .fileImporter(
            isPresented: $showCVPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleCVSelection(result)
        }
        .confirmationDialog(
            LocalizedStringKey("mp.profile.upl_confirm_photo"),
            isPresented: $showDeletePhotoConfirm,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("mp.profile.upl_delete"), role: .destructive) {
                Task { await vm.deleteFile(kind: "photo") }
            }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            LocalizedStringKey("mp.profile.upl_confirm_cv"),
            isPresented: $showDeleteCVConfirm,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("mp.profile.upl_delete"), role: .destructive) {
                Task { await vm.deleteFile(kind: "cv") }
            }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
        }
    }

    private var photoRow: some View {
        let hasPhoto = vm.photoSignedURL != nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey("mp.profile.lbl_photo"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                Spacer()
                if vm.isUploadingPhoto {
                    ProgressView().tint(Color.ssGreen)
                } else if hasPhoto {
                    Text(LocalizedStringKey("mp.profile.upl_no_photo"))
                        .font(.ssCaption)
                        .foregroundStyle(.clear) // placeholder for alignment
                }
            }
            Text(LocalizedStringKey("mp.profile.upl_photo_hint"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $photoPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        LocalizedStringKey(hasPhoto ? "common.refresh" : "mp.profile.upl_btn"),
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ssCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                .disabled(vm.isUploadingPhoto)

                if hasPhoto {
                    Button(role: .destructive) {
                        showDeletePhotoConfirm = true
                    } label: {
                        Label(LocalizedStringKey("mp.profile.upl_delete"),
                              systemImage: "trash")
                            .font(.ssCaption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.ssCream)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
                    }
                }
            }
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
    }

    private var cvRow: some View {
        let hasCV = vm.cvSignedURL != nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey("mp.profile.lbl_cv"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                Spacer()
                if vm.isUploadingCV {
                    ProgressView().tint(Color.ssGreen)
                }
            }
            Text(LocalizedStringKey("mp.profile.upl_cv_hint"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            HStack(spacing: 8) {
                Button {
                    showCVPicker = true
                } label: {
                    Label(
                        LocalizedStringKey(hasCV ? "common.refresh" : "mp.profile.upl_btn"),
                        systemImage: "doc.badge.plus"
                    )
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ssCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                .disabled(vm.isUploadingCV)

                if hasCV, let url = vm.cvSignedURL {
                    Link(destination: url) {
                        Label(LocalizedStringKey("mp.profile.upl_open_cv"),
                              systemImage: "arrow.up.right.square")
                            .font(.ssCaption.weight(.semibold))
                            .foregroundStyle(Color.ssGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.ssCream)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                    }
                    Button(role: .destructive) {
                        showDeleteCVConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.ssCaption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.ssCream)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                vm.toast = .error(ErrorLocalization.localize("mp.profile.upl_failed"))
                photoPickerItem = nil
                return
            }
            let name = "photo.jpg"
            await vm.uploadPhoto(data, originalFilename: name)
            photoPickerItem = nil
        }
    }

    private func handleCVSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Security-scoped resource for files picked from Files app.
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                Task { await vm.uploadCV(data, originalFilename: url.lastPathComponent) }
            } catch {
                vm.toast = .error(ErrorLocalization.localize("mp.profile.upl_failed"))
            }
        case .failure:
            vm.toast = .error(ErrorLocalization.localize("mp.profile.upl_failed"))
        }
    }

    // MARK: - Language + Sign out

    private var languageButton: some View {
        Button {
            let raw = UIApplication.openSettingsURLString
            guard let url = URL(string: raw) else {
                showSettingsFallback = true
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                Task { @MainActor in
                    if !success { showSettingsFallback = true }
                }
            }
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

    private var supportButton: some View {
        Button {
            showSupportSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lifepreserver")
                Text(LocalizedStringKey("support.tab_title"))
            }
            .font(.ssBodyBold)
            .foregroundStyle(Color.ssGreen)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.ssGreen.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .sheet(isPresented: $showSupportSheet) {
            SupportSubmitSheet(isPresented: $showSupportSheet)
        }
    }

    // MARK: - Error state

    private func errorState(_ message: String) -> some View {
        let display = message.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "err.unknown")
            : message
        return VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(display)
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
