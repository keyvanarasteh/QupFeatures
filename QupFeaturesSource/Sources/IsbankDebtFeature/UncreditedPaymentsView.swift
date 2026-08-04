import DesignSystem
import SwiftUI

/// Dosyaya işlenmemiş, belgeli ödemeler — editable, and the whole reason the
/// real balance differs from the official one.
struct UncreditedPaymentsView: View {
    @Environment(\.cupertinoColors) private var colors

    @Binding var uncredited: UncreditedPaymentInputs

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionHeader(
                        "Dosyaya İşlenmemiş Ödemeler",
                        subtitle: "Belgeli / doğrulanmış",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    Text("Banka ekstresi, dekont ve Fibabanka hesap hareketleriyle belgeli, ama resmî icra dosyası \"yatan para\" kaleminde görünmeyen ödemeler. Alanları değiştirdiğinizde ana sayfadaki \"Gerçek Kalan Borç\" anlık güncellenir.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        paymentRow(
                            title: "İş Bankası \"TAKAS YOLUYLA TAKİP BORCU TAHSİLATI\" kesintileri (doğrulanmış)",
                            source: RateReference.takasSource,
                            value: $uncredited.takas
                        )
                        SoftDivider()
                        paymentRow(
                            title: "Fibabanka'dan Av. Habil Yazıcı'nın şahsi İş Bankası hesabına FAST (7 ödeme, tamamı belgeli)",
                            source: RateReference.fibaSource,
                            value: $uncredited.fiba
                        )
                        SoftDivider()
                        ComputedRow(
                            title: "Dosyaya İşlenmemiş Ödemeler Toplamı",
                            value: uncredited.total,
                            emphasis: .result
                        )
                    }
                }

                SourceNote("Tam çapraz-kontrol ve SHA-256 dosya bütünlük kaydı: odeme-dogrulama-listesi.md · önceki (düzeltilen) mutabakat: payment-full.md")
            }
        }
        .navigationTitle("İşlenmemiş Ödemeler")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func paymentRow(title: String, source: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(colors.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AmountField(value: value, accessibilityLabel: title)
            }
            SourceNote(source)
        }
    }
}
