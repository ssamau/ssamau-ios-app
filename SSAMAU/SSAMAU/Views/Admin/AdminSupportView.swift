import SwiftUI

/// Admin-facing: launch the standard SupportSubmitSheet. Real ticket
/// management lives in DevPagesView (superadmin-only support.list /
/// support.updateStatus).
struct AdminSupportView: View {
    @State private var submitting: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lifepreserver")
                .font(.system(size: 48)).foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("support.tab_title"))
                .font(.ssH2).foregroundStyle(Color.ssGreen)
            GoldRule(width: 32)
            Text(LocalizedStringKey("support.sheet_title"))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button {
                submitting = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                    Text(LocalizedStringKey("support.submit_btn"))
                }
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssCream)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color.ssGreen)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
        .navigationTitle(LocalizedStringKey("ap.tabs.support"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $submitting) {
            SupportSubmitSheet(isPresented: $submitting)
        }
    }
}
