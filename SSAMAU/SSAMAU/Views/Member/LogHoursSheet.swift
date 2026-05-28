import SwiftUI

/// Sheet for logging volunteer hours against an Attended assignment.
/// Spec §8.7.
struct LogHoursSheet: View {
    let viewModel: HoursViewModel
    @Binding var isPresented: Bool

    @State private var selectedAssignment: Assignment?
    @State private var before: String = "0"
    @State private var during: String = "0"
    @State private var after: String = "0"
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    assignmentPicker
                    hoursFields
                    notesField
                    submit
                    if viewModel.loggableAssignments.isEmpty {
                        Text(LocalizedStringKey("mp.hours.no_loggable"))
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 80)   // room for toast overlay
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .ssToast(Binding(
                get: { viewModel.toast },
                set: { viewModel.toast = $0 }
            ))
            .navigationTitle(LocalizedStringKey("mp.hours.log_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) {
                        isPresented = false
                    }
                    .foregroundStyle(Color.ssGrey)
                    .disabled(viewModel.isLogging)
                }
            }
            .onAppear {
                if selectedAssignment == nil {
                    selectedAssignment = viewModel.loggableAssignments.first
                }
            }
        }
    }

    private var assignmentPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.hours.pick_assignment"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            Menu {
                ForEach(viewModel.loggableAssignments) { a in
                    Button {
                        selectedAssignment = a
                    } label: {
                        Text("\(a.displayProject) — \(a.displayRole)")
                    }
                }
            } label: {
                HStack {
                    if let a = selectedAssignment {
                        Text("\(a.displayProject) — \(a.displayRole)")
                            .font(.ssBody)
                            .foregroundStyle(Color.ssCharcoal)
                            .lineLimit(2)
                    } else {
                        Text(LocalizedStringKey("mp.hours.no_loggable_short"))
                            .font(.ssBody)
                            .foregroundStyle(Color.ssGrey)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.ssGrey)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ssPale)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ssLight, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(viewModel.loggableAssignments.isEmpty)
        }
    }

    private var hoursFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("mp.hours.fields_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            HStack(spacing: 10) {
                hoursField(label: "mp.hours.before", text: $before)
                hoursField(label: "mp.hours.during", text: $during)
                hoursField(label: "mp.hours.after",  text: $after)
            }
            Text(LocalizedStringKey("mp.hours.fields_hint"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
        }
    }

    private func hoursField(label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.ssTiny)
                .foregroundStyle(Color.ssGrey)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssCharcoal)
                .padding(10)
                .background(Color.ssPale)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ssLight, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.hours.notes_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            TextField(
                LocalizedStringKey("mp.hours.notes_placeholder"),
                text: $notes,
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
            guard let a = selectedAssignment else { return }
            Task {
                let ok = await viewModel.logHours(
                    assignment: a,
                    before: Double(before) ?? 0,
                    during: Double(during) ?? 0,
                    after:  Double(after)  ?? 0,
                    notes:  notes
                )
                if ok { isPresented = false }
            }
        } label: {
            ZStack {
                Text(LocalizedStringKey("mp.hours.submit"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .opacity(viewModel.isLogging ? 0 : 1)
                if viewModel.isLogging {
                    ProgressView().tint(Color.ssCream)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(canSubmit ? Color.ssGreen : Color.ssGrey)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        guard selectedAssignment != nil, !viewModel.isLogging else { return false }
        let total = (Double(before) ?? 0) + (Double(during) ?? 0) + (Double(after) ?? 0)
        return total > 0
    }
}
