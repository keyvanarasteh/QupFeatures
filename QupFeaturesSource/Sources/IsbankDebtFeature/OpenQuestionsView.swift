import DesignSystem
import SwiftUI

/// Kalemler that could move the final figure but aren't in it, because each
/// needs a document or filing before it can be quantified.
///
/// The source page cross-links three of these back to the rate tables; here
/// that becomes a push onto the same navigation stack rather than swapping one
/// modal for another.
struct OpenQuestionsView: View {
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionHeader(
                        "Ayrıca Değerlendirilmesi Gereken Kalemler",
                        subtitle: "Hesaba dahil edilmedi",
                        systemImage: "exclamationmark.triangle"
                    )
                    Text("Bu kalemler \"Gerçek Kalan Borç\" hesabına dahil edilmedi çünkü tutarları kesinleşmemiş veya doğrulanması ayrı bir belge/başvuru gerektiriyor. Yine de borcun nihai tutarını etkileyebilecek açık noktalardır.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(RateReference.openQuestions) { note in
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(note.title)
                                .font(Theme.Typography.headline)
                                .foregroundStyle(colors.fg)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(note.body)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(colors.fg)
                                .fixedSize(horizontal: false, vertical: true)
                            SoftDivider()
                            SourceNote(note.source)
                            if note.linksToRates {
                                NavigationLink {
                                    RateReferenceView()
                                } label: {
                                    Label("Ay Ay Faiz Oranları", systemImage: "percent")
                                        .font(Theme.Typography.caption)
                                }
                                .buttonStyle(.ghost)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Açık Kalemler")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
