import DesignSystem
import SwiftUI

/// Ay ay TCMB azami oranları, harç kuralları ve kaynaklar.
///
/// The source page renders this as two ~6-column tables in a horizontally
/// scrolling box. On a phone that means reading a spreadsheet through a slot,
/// so each month becomes a row instead: ceilings on the right where they can be
/// compared down the column, and the tier/bank-rate/source line underneath.
struct RateReferenceView: View {
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                header

                appliedRatesSection
                feeRulesSection
                monthlySection(
                    number: "3",
                    title: "Dosya 2024/162868 — Ek Hesap / KMH",
                    description: RateReferenceView.file1Description,
                    rows: RateReference.file1Rates,
                    riskLegend: "TCMB tavanı %5,30'un altına düştü — banka indirmediyse fazla faiz"
                )
                monthlySection(
                    number: "4",
                    title: "Dosya 2024/234554 — Kredi Kartı",
                    description: RateReferenceView.file2Description,
                    rows: RateReference.file2Rates,
                    riskLegend: "TCMB tavanı %4,55'in altına düştü — banka indirmediyse fazla faiz"
                )
                restructuringSection
                nextStepSection
            }
        }
        .navigationTitle("Faiz Oranları ve Harç Kuralları")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(
                "Kullanılan Faiz Oranları ve Harç Kuralları — Ay Ay",
                subtitle: "Ağustos 2024 – Ağustos 2026",
                systemImage: "percent"
            )
            Text(RateReferenceView.headerNote)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 1

    private var appliedRatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("1. Takip Başlangıcında Fiilen Uygulanan Oranlar")
            SourceNote("Kaynak: progress/10 §2 (Takip Talebi'nden)")

            ForEach(RateReference.appliedRates) { row in
                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(row.file)
                                .font(Theme.Typography.headline)
                                .foregroundStyle(colors.fg)
                            Spacer()
                            StatusBadge(row.verdict, tone: .success)
                        }
                        labelled("Takip Tarihi", row.date)
                        labelled("Borç Türü", row.debtKind)
                        labelled("Uygulanan Aylık Oran", row.monthlyRate, mono: true)
                        labelled("Yıllık Karşılık", row.annualRate, mono: true)
                        labelled("O Tarihteki TCMB Tavanı", row.ceiling)
                    }
                }
            }
        }
    }

    // MARK: - 2

    private var feeRulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("2. Sabit Harç / Kesinti Oranları (Faiz Değildir)")
            Text("492 Sayılı Harçlar Kanunu (1) Sayılı Tarife, B Bölümü. Bu bölüm 04.08.2026 tarihinde web'den ayrıca araştırılıp doğrulandı.")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(RateReference.feeRules) { rule in
                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(rule.title)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(colors.fg)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(rule.body)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.fg)
                            .fixedSize(horizontal: false, vertical: true)
                        SoftDivider()
                        SourceNote(rule.source)
                    }
                }
            }
        }
    }

    // MARK: - 3 & 4

    private func monthlySection(
        number: String,
        title: String,
        description: String,
        rows: [MonthlyRateRow],
        riskLegend: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("\(number). \(title): TCMB Azami Faizi, AY AY")
            Text(description)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)

            legend(riskLegend: riskLegend)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(rows) { row in
                    MonthlyRateCard(row: row)
                }
            }

            Text(RateReference.futureMonthsNote)
                .font(Theme.Typography.caption2)
                .italic()
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legend(riskLegend: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            legendRow(color: colors.border, text: "Takipteki sabit oranla aynı / henüz tavan düşmedi")
            legendRow(color: colors.danger, text: riskLegend)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 3)
            Text(text)
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 5 & 6

    private var restructuringSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("5. Yapılandırma İçin Ayrı Kural")
            Text("Peşin kapama / sulh pazarlığı için referans.")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)

            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(RateReference.restructuringRules.enumerated()), id: \.offset) { _, rule in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Text("•").foregroundStyle(colors.mutedFg)
                            Text(rule)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(colors.fg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    SoftDivider()
                    SourceNote("Kaynak: classified/faiz-oranlari-2024-2026/README.md (ham kaynaklar: sources.md, TCMB/BDDK duyuruları)")
                }
            }
        }
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("6. Sonraki Doğrulama Adımı")
            CardView {
                Text(RateReference.nextVerificationStep)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.headline)
            .foregroundStyle(colors.fg)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func labelled(_ key: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(key)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
            Spacer(minLength: Theme.Spacing.sm)
            Text(value)
                .font(mono ? Theme.Typography.code : Theme.Typography.caption)
                .foregroundStyle(colors.fg)
                .multilineTextAlignment(.trailing)
        }
    }

    private static let headerNote = """
    Dosyalarda uygulanan başlangıç oranları, sabit harç oranları ve Ağustos 2024 – Ağustos 2026 arasının \
    TAMAMI için ay ay TCMB azami (tavan) oranları. Rakamlar özet README yerine doğrudan TCMB'nin birincil \
    PDF/HTML kaynaklarından tek tek okunup doğrulandı. Dosya Hesabı belgeleri yalnızca tek bir toplam faiz \
    veriyor; dönemsel kırılımı banka/UYAP vermiyor — bu yüzden "banka bu ayda gerçekte ne oran uyguladı" \
    alanı bilinmiyor olarak işaretlendi.
    """

    private static let file1Description = """
    Kategori: "Nakit Çekim veya Kullanım İşlemlerinde Uygulanacak (kredili mevduat hesapları için de \
    geçerlidir)". 08.2024–10.2024 → PDF sayfa 2; 11.2024–12.2025 → aynı PDF sayfa 1; 01.2026–07.2026 → \
    tcmb-kredi-karti-azami-faiz-guncel.html. Takipte uygulanan sabit oran %5,30/ay (gecikme) idi. Kırmızı \
    satırlar, TCMB tavanının bu %5,30'un ALTINA düştüğü aylardır.
    """

    private static let file2Description = """
    Kart bakiyesi ~131.535 TL. Kasım 2024 öncesi kademesiz genel oran geçerli; Kasım 2024'ten itibaren \
    kademeli sisteme göre "25.000–150.000 TL arası" dilimi (Ocak 2026'dan itibaren eşik değişikliğiyle \
    "30.000–180.000 TL arası" — aynı orta dilim) geçerlidir. Takipte uygulanan sabit oran %4,55/ay \
    (gecikme) idi.
    """
}

/// One month, as a row: ceilings aligned right so they can be scanned down the
/// column, everything else on secondary lines.
private struct MonthlyRateCard: View {
    @Environment(\.cupertinoColors) private var colors

    let row: MonthlyRateRow

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(row.isRisk ? colors.danger : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(row.month)
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(colors.fg)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(row.contractual)
                            .font(Theme.Typography.code)
                            .foregroundStyle(colors.fg)
                        Text(row.overdue)
                            .font(Theme.Typography.code)
                            .fontWeight(.semibold)
                            .foregroundStyle(row.isRisk ? colors.danger : colors.fg)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Azami akdi \(row.contractual), azami gecikme \(row.overdue)")
                }

                if let tier = row.tier {
                    detail("Kademe", tier)
                }
                detail("Banka oranı", row.bankRate)
                detail("Kaynak", row.source)
            }
            .padding(Theme.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(row.isRisk ? colors.danger.opacity(0.10) : colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private func detail(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            Text("\(key):")
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
            Text(value)
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
