import Charts
import DesignSystem
import SwiftUI

/// Gerçek Borç — Tüm Ödemeler: the month-by-month re-derivation.
///
/// The calculator tab subtracts lump sums; this one replays both files month by
/// month against every documented payment, so you can see *when* the balance
/// crosses zero rather than only the end figure.
struct RealDebtView: View {
    @Environment(\.cupertinoColors) private var colors

    @State private var scenario: DebtScenario = .official

    private var result: SimulationResult {
        DebtSimulation.run(scenario: scenario)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            scenarioPicker
            mahsupPriorityNote
            assumptionNote
            resultBanner
            statGrid

            if scenario.hasMonthlyBreakdown {
                chart
                ledger
                Text(DebtSimulation.methodologyNote)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(colors.mutedFg)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Controls

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Senaryo")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
            Picker("Senaryo", selection: $scenario) {
                ForEach(DebtScenario.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("debt-scenario-picker")
        }
    }

    private var mahsupPriorityNote: some View {
        CardView {
            Text(DebtSimulation.mahsupPriorityNote)
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var assumptionNote: some View {
        Text(scenario.assumption)
            .font(Theme.Typography.caption2)
            .foregroundStyle(colors.mutedFg)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Headline

    private var resultBanner: some View {
        let overpaid = result.isOverpaid
        return VStack(spacing: Theme.Spacing.sm) {
            Text(overpaid ? "🎉 FAZLA ÖDENMİŞ" : "GERÇEK KALAN BORÇ (SENARYO)")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .multilineTextAlignment(.center)
            Text(TurkishLira.formatted(abs(result.combined)))
                .font(Theme.Typography.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(overpaid ? colors.success : colors.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(overpaid
                ? "Bu senaryoda borç kapanmış; hesaplanan tutar kadar fazla ödeme birikmiş görünüyor."
                : "Anapara + Faiz (aylık simülasyon, tüm ödemeler düşülmüş) + sabit harç/vekâlet")
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(overpaid ? colors.success.opacity(0.12) : colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(overpaid ? colors.success : colors.primary, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }

    private var statGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)],
            spacing: Theme.Spacing.md
        ) {
            StatTile(
                title: "Dosya1 Gerçek Bakiye",
                value: result.file1Balance,
                tone: result.file1Balance <= 0 ? .success : .neutral
            )
            StatTile(
                title: "Dosya2 Gerçek Bakiye",
                value: result.file2Balance,
                tone: result.file2Balance <= 0 ? .success : .neutral
            )
            StatTile(title: "Toplam Ödenen (tüm kanallar, tekrarsız)", value: result.totalPaid)
            StatTile(title: "Resmî Bakiye (referans)", value: DebtSimulation.officialBalanceReference)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Aylık Bakiye Seyri")
                .font(Theme.Typography.headline)
                .foregroundStyle(colors.fg)

            Chart {
                // Below this line the debt is closed and the excess is
                // overpayment, so it gets its own band rather than a gridline.
                if let minimum = chartMinimum, minimum < 0 {
                    RectangleMark(
                        yStart: .value("Alt", minimum),
                        yEnd: .value("Sıfır", 0)
                    )
                    .foregroundStyle(colors.success.opacity(0.12))
                }

                ForEach(result.rows) { row in
                    LineMark(
                        x: .value("Ay", row.month),
                        y: .value("Bakiye", row.file1Balance),
                        series: .value("Seri", "Dosya1 (KMH)")
                    )
                    .foregroundStyle(colors.primary)

                    if let balance = row.file2Balance {
                        LineMark(
                            x: .value("Ay", row.month),
                            y: .value("Bakiye", balance),
                            series: .value("Seri", "Dosya2 (Kredi Kartı)")
                        )
                        .foregroundStyle(colors.info)
                    }

                    LineMark(
                        x: .value("Ay", row.month),
                        y: .value("Bakiye", row.totalBalance),
                        series: .value("Seri", "Toplam")
                    )
                    .foregroundStyle(colors.fg)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                RuleMark(y: .value("Sıfır", 0))
                    .foregroundStyle(colors.mutedFg)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxis {
                // Every third month; 25 labels would overlap on a phone.
                AxisMarks(values: stridedMonths) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let month = value.as(String.self) {
                            Text(month).font(Theme.Typography.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(TurkishLira.plain(amount / 1000) + "b")
                                .font(Theme.Typography.caption2)
                        }
                    }
                }
            }
            .frame(height: 240)

            chartLegend
        }
    }

    private var chartLegend: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            legendItem(colors.primary, "Dosya1 (KMH)")
            legendItem(colors.info, "Dosya2 (Kredi Kartı)")
            legendItem(colors.fg, "Toplam")
            legendItem(colors.success.opacity(0.5), "Yeşil alan = borç kapanmış, fazla ödeme birikiyor")
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Capsule().fill(color).frame(width: 14, height: 3)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chartMinimum: Double? {
        result.rows
            .flatMap { [$0.file1Balance, $0.file2Balance ?? 0, $0.totalBalance] }
            .min()
    }

    private var stridedMonths: [String] {
        let months = result.rows.map(\.month)
        guard !months.isEmpty else { return [] }
        return months.enumerated()
            .filter { $0.offset % 3 == 0 || $0.offset == months.count - 1 }
            .map(\.element)
    }

    // MARK: - Ledger

    private var ledger: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Aylık Döküm")
                .font(Theme.Typography.headline)
                .foregroundStyle(colors.fg)

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(result.rows) { row in
                    LedgerRowView(row: row)
                }
            }
        }
    }
}

/// One ledger month. The source page uses a seven-column table in a scroll box;
/// on a phone the two files stack instead, which keeps every figure without a
/// horizontal scroll inside a vertical one.
private struct LedgerRowView: View {
    @Environment(\.cupertinoColors) private var colors

    let row: CombinedLedgerRow

    private var isClosed: Bool { row.totalBalance < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.month)
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(colors.fg)
                Spacer()
                Text(TurkishLira.formatted(row.totalBalance))
                    .font(Theme.Typography.code)
                    .fontWeight(.semibold)
                    .foregroundStyle(isClosed ? colors.success : colors.fg)
            }

            fileLine(
                label: "D1",
                rate: row.file1Rate,
                balance: row.file1Balance
            )
            if let rate = row.file2Rate, let balance = row.file2Balance {
                fileLine(label: "D2", rate: rate, balance: balance)
            }
            if row.paidThisMonth > 0 {
                HStack {
                    Text("O ay ödenen")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(colors.mutedFg)
                    Spacer()
                    Text(TurkishLira.formatted(row.paidThisMonth))
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(colors.success)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(isClosed ? colors.success.opacity(0.08) : colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func fileLine(label: String, rate: Double, balance: Double) -> some View {
        HStack {
            Text("\(label) · %\(TurkishLira.plain(rate))")
                .font(Theme.Typography.caption2)
                .foregroundStyle(colors.mutedFg)
            Spacer()
            Text(TurkishLira.formatted(balance))
                .font(Theme.Typography.caption2)
                .foregroundStyle(balance < 0 ? colors.success : colors.mutedFg)
        }
    }
}
