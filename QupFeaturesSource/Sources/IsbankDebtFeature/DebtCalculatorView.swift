import DesignSystem
import SwiftUI

/// Gerçek Borç Hesaplama — İş Bankası icra dosyaları.
///
/// Ported from `gercek-borc-hesaplama.html`. Every amount stays editable and
/// every total recomputes as you type, because the page's job is to let you
/// re-run the arithmetic against your own current figures rather than to
/// present one frozen result.
public struct DebtCalculatorView: View {
    @Environment(\.cupertinoColors) private var colors

    /// Which of the two tabs is showing.
    enum Tab: String, CaseIterable, Identifiable {
        case calculator
        case realDebt

        var id: Self { self }

        var title: String {
            switch self {
            case .calculator: "Hesap Makinesi"
            case .realDebt: "Tüm Ödemeler"
            }
        }
    }

    @State private var tab: Tab = .calculator
    @State private var calculation = DebtCalculation.default
    @State private var confirmReset = false

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                header

                Picker("Sekme", selection: $tab) {
                    ForEach(Tab.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("debt-tabs")

                switch tab {
                case .calculator: calculatorTab
                case .realDebt: RealDebtView()
                }
            }
        }
        .navigationTitle("Gerçek Borç")
        .alert("Varsayılan değerlere sıfırla?", isPresented: $confirmReset) {
            Button("Sıfırla", role: .destructive) { calculation = .default }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Girdiğiniz tüm tutarlar resmî dosya hesabındaki varsayılanlarla değiştirilecek.")
        }
    }

    // MARK: - Tab 1

    @ViewBuilder
    private var calculatorTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            DisclaimerBanner(text: DebtCalculatorView.disclaimer)
            formulaSection
            fileSection(
                title: "Dosya 2024/162868",
                subtitle: "Ek Hesap / KMH",
                paidLabel: "Yatan Para (maaş haczi — 18 kesinti)",
                source: "Kaynak: Dosya Hesabı 162868 · progress/12",
                inputs: $calculation.file1
            )
            fileSection(
                title: "Dosya 2024/234554",
                subtitle: "Kredi Kartı",
                paidLabel: "Yatan Para",
                source: "Kaynak: Dosya Hesabı 234554 · progress/09 · progress/12",
                inputs: $calculation.file2
            )
            referenceLinks
            finalResult
            statGrid
            resetButton
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(
                "Gerçek Borç Hesaplama Formülü",
                subtitle: "İş Bankası icra dosyaları",
                systemImage: "banknote"
            )
            Text("Resmî dosya bakiyesi ile dosyaya işlenmemiş belgeli ödemeler mahsup edildiğinde ortaya çıkan gerçek kalan borç. Tüm alanlar düzenlenebilir; toplamlar anlık güncellenir.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)

            // Stacked rather than flowed: the labels are long enough that a
            // wrapping row would break mid-chip on a phone.
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                CupertinoChip("Borçlu: Keyvan Arasteh Abbasabad")
                CupertinoChip("Dosya 1: 2024/162868 (Ek Hesap / KMH)")
                CupertinoChip("Dosya 2: 2024/234554 (Kredi Kartı)")
                CupertinoChip("Hazırlanma: 09.07.2026")
            }
        }
    }

    // MARK: - Formula

    private var formulaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Genel Formül")
                .font(Theme.Typography.headline)
                .foregroundStyle(colors.fg)
            Text("Gerçek kalan borç, resmî icra dosyası bakiyesinden — bankaya/avukata ödendiği belgeyle sabit olduğu hâlde dosyaya hiç işlenmemiş ödemelerin düşülmesiyle bulunur.")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
            FormulaBlock(text: DebtCalculatorView.formula)
        }
    }

    // MARK: - One enforcement file

    private func fileSection(
        title: String,
        subtitle: String,
        paidLabel: String,
        source: String,
        inputs: Binding<EnforcementFileInputs>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(colors.fg)
                Spacer(minLength: Theme.Spacing.sm)
                StatusBadge("Resmî UYAP Dosya Hesabı", tone: .info)
            }
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)

            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    AmountRow(title: "Takipte Kesinleşen Anapara", value: inputs.principal)
                    AmountRow(title: "Toplam Faiz", value: inputs.interest)
                    AmountRow(title: "Vekâlet Ücreti", value: inputs.attorney)
                    AmountRow(title: "Masraf", value: inputs.cost)
                    AmountRow(title: "BSMV", value: inputs.bsmv)
                    AmountRow(title: "KKDF", value: inputs.kkdf)
                    AmountRow(title: "Tahsil Harcı", value: inputs.harc)

                    SoftDivider()
                    ComputedRow(title: "Toplam Alacak", value: inputs.wrappedValue.totalClaim)

                    SoftDivider()
                    AmountRow(title: paidLabel, value: inputs.paid)
                    ComputedRow(
                        title: "Resmî Bakiye Borç",
                        value: inputs.wrappedValue.officialBalance,
                        emphasis: .result
                    )
                }
            }

            SourceNote(source)
        }
    }

    // MARK: - Reference sheets

    private var referenceLinks: some View {
        VStack(spacing: Theme.Spacing.sm) {
            NavigationLink {
                RateReferenceView()
            } label: {
                Label("Ay Ay Faiz Oranları, Harç Kuralları ve Kaynaklar", systemImage: "percent")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.secondary)

            NavigationLink {
                UncreditedPaymentsView(uncredited: $calculation.uncredited)
            } label: {
                Label("Dosyaya İşlenmemiş Ödemeler (Görüntüle / Düzenle)", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.secondary)

            NavigationLink {
                OpenQuestionsView()
            } label: {
                Label("Ayrıca Değerlendirilmesi Gereken Kalemler", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.secondary)
        }
    }

    // MARK: - Result

    private var finalResult: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("GERÇEK KALAN BORÇ (İKİ DOSYA BİRLİKTE)")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .multilineTextAlignment(.center)
            Text(TurkishLira.formatted(calculation.realBalance))
                .font(Theme.Typography.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(colors.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Toplam Alacak (Dosya1 + Dosya2) − (Yatan Para + TAKAS + Avukata Elden Ödemeler)")
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(colors.primary, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }

    private var statGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)],
            spacing: Theme.Spacing.md
        ) {
            StatTile(title: "İki Dosya Toplam Alacak", value: calculation.totalClaim)
            StatTile(title: "Resmî Kalan Bakiye (dosyaya işlenen ödemeye göre)", value: calculation.officialBalance)
            StatTile(title: "Toplam Belgeli Ödeme (tüm kanallar)", value: calculation.totalPaid)
            StatTile(title: "Resmî bakiye ile gerçek bakiye farkı", value: calculation.difference, tone: .danger)
        }
    }

    private var resetButton: some View {
        Button("Varsayılan Değerlere Sıfırla", systemImage: "arrow.counterclockwise") {
            confirmReset = true
        }
        .buttonStyle(.secondary)
        .frame(maxWidth: .infinity)
        .disabled(calculation == .default)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.xs) {
            SourceNote("Kaynaklar: payment-full.md · odeme-dogrulama-listesi.md · progress/12-DOSYA-HESABI-kesin-mutabakat.md")
            SourceNote("Bu belge resmî değildir; kişisel dosya takibi ve hukuk bürosuna/D6 dilekçesine temel oluşturmak amacıyla hazırlanmıştır.")
        }
    }

    // MARK: - Copy

    private static let disclaimer = """
    Bu sayfa bilgilendirme/kişisel takip amaçlıdır; resmî bilirkişi raporu veya icra dosyası hesabı yerine \
    geçmez. Varsayılan rakamlar progress/12-DOSYA-HESABI-kesin-mutabakat.md (resmî UYAP Dosya Hesabı \
    dökümleri) ve odeme-dogrulama-listesi.md (banka/Fibabanka ekstresiyle satır satır doğrulanmış tutarlar) \
    kaynaklarından alınmıştır. Alanları kendi güncel verinizle değiştirip yeniden hesaplayabilirsiniz.
    """

    private static let formula = """
    Dosya Toplam Alacağı  = Anapara + Toplam Faiz + Vekâlet Ücreti
                            + Masraf + BSMV + KKDF + Tahsil Harcı

    Resmî Dosya Bakiyesi  = Dosya Toplam Alacağı − Dosyaya İşlenen Ödeme

    GERÇEK KALAN BORÇ     = (Dosya1 Toplam Alacak + Dosya2 Toplam Alacak)
                            − (Dosyaya İşlenen Ödemeler
                               + TAKAS Kesintileri
                               + Avukata Elden Ödemeler)
    """
}
