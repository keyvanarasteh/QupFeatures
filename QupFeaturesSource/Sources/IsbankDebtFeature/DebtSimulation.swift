import Foundation

/// Which interest assumption the month-by-month run uses.
public enum DebtScenario: String, CaseIterable, Identifiable, Sendable {
    /// The bank's own declared total interest — no monthly breakdown exists.
    case official
    /// Each month at TCMB's verified ceiling: the most the bank could lawfully charge.
    case ceiling
    /// The takip-start rate, never lowered — the worst case if the bank ignored the cuts.
    case flat

    public var id: Self { self }

    public var title: String {
        switch self {
        case .official: "Banka Resmi Rakamı"
        case .ceiling: "TCMB Tavanı — Yasal Yöntem"
        case .flat: "Hiç İndirilmediyse"
        }
    }

    public var assumption: String {
        switch self {
        case .official:
            "Bankanın Dosya Hesabı'nda beyan ettiği toplam faiz (241.505,75 + 102.250,06 TL) sabit " +
                "kullanılır; günlük kırılım yok. TAKAS + Fibabanka fazlası, mahsup kuralına göre önce " +
                "Dosya1'in resmî bakiyesini kapatır, taşan kısım Dosya2'ye geçer."
        case .ceiling:
            "Yasal yöntem: takip tarihinden (15.08.2024 / 14.10.2024) bugüne (04.08.2026) gün esaslı " +
                "basit faiz, TCMB'nin doğrulanmış azami tavan oranıyla — ve TBK m.100–102 mahsup " +
                "sırasıyla iki dosya BİRLİKTE işleniyor (bkz. mahsup önceliği notu). Bankanın " +
                "uygulayabileceği en yüksek yasal senaryo."
        case .flat:
            "Aynı gün esaslı/TBK m.100–102 yöntemi, ama oran hiç düşürülmeden (%5,30 / %4,55) Ağustos " +
                "2026'ya kadar sabit uygulanmış varsayılır — banka tavanı hiç indirmediyse ortaya " +
                "çıkacak en kötümser senaryo."
        }
    }

    /// Only the simulated scenarios produce a chart and a ledger.
    public var hasMonthlyBreakdown: Bool { self != .official }
}

/// One payment, as recorded in the verified payment list.
public struct DebtPayment: Equatable, Sendable {
    public let month: String
    public let amount: Double
    /// True where the dekont names the Ek Hesap debt only, so the money can't
    /// be split across both files.
    public let file1Only: Bool

    public init(month: String, amount: Double, file1Only: Bool = false) {
        self.month = month
        self.amount = amount
        self.file1Only = file1Only
    }
}

/// A month of the combined run, as the ledger table shows it.
public struct CombinedLedgerRow: Identifiable, Equatable, Sendable {
    public var id: String { month }
    public let month: String
    public let file1Rate: Double
    public let file1Balance: Double
    public let file2Rate: Double?
    public let file2Balance: Double?
    public let paidThisMonth: Double
    public let totalBalance: Double
}

/// The outcome of one scenario.
public struct SimulationResult: Equatable, Sendable {
    public let file1Balance: Double
    public let file2Balance: Double
    public let totalPaid: Double
    public let rows: [CombinedLedgerRow]

    public var combined: Double { file1Balance + file2Balance }
    /// Once the combined balance crosses zero the debt is closed and the excess
    /// is money paid beyond what was owed.
    public var isOverpaid: Bool { combined <= 0 }
}

/// Month-by-month re-derivation of both files from the verified payment record.
///
/// The official file account gives one lump interest figure and no periodic
/// breakdown, so the only way to test it is to re-run the arithmetic: day-based
/// simple interest on the outstanding principal, payments applied to accrued
/// interest before principal (TBK m.100), across every documented payment
/// channel rather than only the ones the file credited.
///
/// Which debt a payment retires is not a free parameter: maaş haczi is bound to
/// file 1 by the İİK "sıra" rule (whichever garnishment reaches the employer
/// first collects alone until that debt is gone); dekontlar that name "ek hesap
/// borcu" explicitly are bound to file 1 by the debtor's own designation (TBK
/// m.101); and everything undesignated (TAKAS, and the Fibabanka transfers that
/// name both debts) falls to file 1 first because its takip started first (TBK
/// m.102), spilling into file 2 only once file 1 is fully retired.
public enum DebtSimulation {
    // MARK: - Fixed figures

    public static let file1Principal: Double = 255_411.49
    public static let file2Principal: Double = 131_673.68

    /// Vekâlet + masraf + BSMV + KKDF + tahsil harcı — held at the bank's own
    /// figures and added once at the end, never compounded into the run.
    public static let file1Charges: Double = 40_865.84 + 673.40 + 12_075.29 + 12_075.29 + 11_621.25
    public static let file2Charges: Double = 21_067.79 + 673.40 + 5_112.50 + 5_112.50 + 11_982.30

    public static let file1OfficialInterest: Double = 241_505.75
    public static let file2OfficialInterest: Double = 102_250.06

    /// Credited to file 1 in the official account.
    public static let file1CreditedPayments: Double = 300_118.55

    /// Quoted on the source page for comparison.
    public static let officialBalanceReference: Double = 551_981.99

    public static let file1StartMonth = "2024-08"
    public static let file2StartMonth = "2024-10"
    public static let currentMonth = "2026-08"

    /// Takip tarihleri — the day-based run starts partway through the start
    /// month for each file.
    public static let file1StartDay = 15
    public static let file2StartDay = 14
    /// The reference "today" the source page was authored against (04.08.2026),
    /// not the device clock — every verified rate and payment is dated relative
    /// to this fixed point.
    public static let referenceDay = 4

    // MARK: - Verified monthly ceilings (azami gecikme faizi, %)

    public static let kmhRates: [String: Double] = [
        "2024-08": 5.30, "2024-09": 5.30, "2024-10": 5.30, "2024-11": 5.30, "2024-12": 5.30,
        "2025-01": 5.30, "2025-02": 5.30, "2025-03": 5.30, "2025-04": 5.30, "2025-05": 5.30,
        "2025-06": 5.30, "2025-07": 5.30,
        "2025-08": 5.05, "2025-09": 5.05, "2025-10": 4.80, "2025-11": 4.80, "2025-12": 4.80,
        "2026-01": 4.55, "2026-02": 4.55, "2026-03": 4.55, "2026-04": 4.55, "2026-05": 4.55,
        "2026-06": 4.55, "2026-07": 4.55, "2026-08": 4.55,
    ]

    public static let cardRates: [String: Double] = [
        "2024-08": 4.55, "2024-09": 4.55, "2024-10": 4.55, "2024-11": 4.55, "2024-12": 4.55,
        "2025-01": 4.55, "2025-02": 4.55, "2025-03": 4.55, "2025-04": 4.55, "2025-05": 4.55,
        "2025-06": 4.55, "2025-07": 4.55,
        "2025-08": 4.30, "2025-09": 4.30, "2025-10": 4.30, "2025-11": 4.30, "2025-12": 4.30,
        "2026-01": 4.05, "2026-02": 4.05, "2026-03": 4.05, "2026-04": 4.05, "2026-05": 4.05,
        "2026-06": 4.05, "2026-07": 4.05, "2026-08": 4.05,
    ]

    /// The rate fixed in each Takip Talebi.
    public static let file1FlatRate: Double = 5.30
    public static let file2FlatRate: Double = 4.55

    // MARK: - Verified payments

    /// 18 maaş haczi deductions — the only channel the official file credits.
    public static let salaryGarnishments: [DebtPayment] = [
        DebtPayment(month: "2025-01", amount: 12_767.90),
        DebtPayment(month: "2025-02", amount: 14_738.85),
        DebtPayment(month: "2025-03", amount: 14_738.85),
        DebtPayment(month: "2025-04", amount: 14_738.85),
        DebtPayment(month: "2025-05", amount: 14_738.86),
        DebtPayment(month: "2025-06", amount: 14_738.86),
        DebtPayment(month: "2025-07", amount: 14_738.86),
        DebtPayment(month: "2025-08", amount: 17_044.20),
        DebtPayment(month: "2025-09", amount: 17_044.20),
        DebtPayment(month: "2025-10", amount: 16_989.13),
        DebtPayment(month: "2025-11", amount: 16_989.13),
        DebtPayment(month: "2025-12", amount: 16_989.13),
        DebtPayment(month: "2026-01", amount: 16_989.13),
        DebtPayment(month: "2026-02", amount: 19_374.52),
        DebtPayment(month: "2026-03", amount: 19_374.52),
        DebtPayment(month: "2026-04", amount: 19_374.52),
        DebtPayment(month: "2026-05", amount: 19_374.52),
        DebtPayment(month: "2026-06", amount: 19_374.52),
    ]

    /// İş Bankası takas deductions — never credited to either file.
    public static let takasDeductions: [DebtPayment] = [
        DebtPayment(month: "2024-08", amount: 4_587.00),
        DebtPayment(month: "2024-08", amount: 520.00),
        DebtPayment(month: "2024-08", amount: 15_000.00),
        DebtPayment(month: "2024-09", amount: 0.26),
        DebtPayment(month: "2024-09", amount: 3_000.00),
        DebtPayment(month: "2024-09", amount: 12_000.00),
        DebtPayment(month: "2024-09", amount: 10_000.00),
        DebtPayment(month: "2024-10", amount: 10_000.00),
        DebtPayment(month: "2024-12", amount: 50.00),
        DebtPayment(month: "2025-11", amount: 100.00),
        DebtPayment(month: "2025-11", amount: 12_741.84),
        DebtPayment(month: "2025-12", amount: 12_741.84),
        DebtPayment(month: "2025-12", amount: 500.00),
        DebtPayment(month: "2025-12", amount: 38.28),
        DebtPayment(month: "2026-01", amount: 38.28),
        DebtPayment(month: "2026-02", amount: 14_530.88),
        DebtPayment(month: "2026-02", amount: 50.00),
        DebtPayment(month: "2026-02", amount: 189.24),
        DebtPayment(month: "2026-02", amount: 30.11),
        DebtPayment(month: "2026-03", amount: 21_101.68),
        DebtPayment(month: "2026-03", amount: 1_800.00),
        DebtPayment(month: "2026-04", amount: 14_530.88),
        DebtPayment(month: "2026-04", amount: 500.00),
        DebtPayment(month: "2026-05", amount: 14_530.88),
        DebtPayment(month: "2026-06", amount: 14_530.88),
        DebtPayment(month: "2026-07", amount: 1_575.07),
    ]

    /// FAST transfers to the attorney's personal account. The first two dekonts
    /// name the Ek Hesap debt only; the rest name both, so only those are split.
    public static let fibabankaTransfers: [DebtPayment] = [
        DebtPayment(month: "2024-09", amount: 15_000.00, file1Only: true),
        DebtPayment(month: "2024-10", amount: 10_000.00, file1Only: true),
        DebtPayment(month: "2024-11", amount: 20_000.00),
        DebtPayment(month: "2024-11", amount: 10_000.00),
        DebtPayment(month: "2025-02", amount: 25_000.00),
        DebtPayment(month: "2025-03", amount: 35_000.00),
        DebtPayment(month: "2025-04", amount: 25_000.00),
    ]

    /// Every documented lira, counted once.
    public static var totalOfAllPayments: Double {
        (salaryGarnishments + takasDeductions + fibabankaTransfers).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Month helpers

    /// Inclusive month range, "YYYY-MM".
    public static func months(from start: String, to end: String) -> [String] {
        guard
            let startYear = Int(start.prefix(4)), let startMonth = Int(start.suffix(2)),
            let endYear = Int(end.prefix(4)), let endMonth = Int(end.suffix(2))
        else { return [] }

        var result: [String] = []
        var year = startYear
        var month = startMonth
        while year < endYear || (year == endYear && month <= endMonth) {
            result.append(String(format: "%04d-%02d", year, month))
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
        return result
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = Calendar(identifier: .gregorian)
        guard
            let date = calendar.date(from: components),
            let range = calendar.range(of: .day, in: .month, for: date)
        else { return 30 }
        return range.count
    }

    // MARK: - The waterfall ledger

    /// The single time-forward pass both files share: day-based simple interest
    /// (aylık oran/30 × o aydaki gün sayısı) accrues each month on the
    /// outstanding principal, then that month's payments retire it in mahsup
    /// order — maaş haczi and explicitly-designated Fibabanka transfers clear
    /// file 1's interest then principal; everything undesignated clears file
    /// 1's interest, then principal, then spills into file 2's interest and
    /// principal, going negative once a file is overpaid.
    static func buildWaterfallLedger(rates1: [String: Double], rates2: [String: Double]) -> [CombinedLedgerRow] {
        let salaryByMonth = Dictionary(grouping: salaryGarnishments, by: \.month)
        let takasByMonth = Dictionary(grouping: takasDeductions, by: \.month)
        let fibaByMonth = Dictionary(grouping: fibabankaTransfers, by: \.month)

        var principal1 = file1Principal, interest1 = 0.0
        var principal2 = file2Principal, interest2 = 0.0

        var year = 2024, month = 8
        let endMonthKey = currentMonth
        var isFirstMonth = true
        var rows: [CombinedLedgerRow] = []

        while String(format: "%04d-%02d", year, month) <= endMonthKey {
            let ym = String(format: "%04d-%02d", year, month)
            let daysInThisMonth = daysInMonth(year: year, month: month)
            let startDay = isFirstMonth ? file1StartDay : 1
            let isCurrentMonth = ym == endMonthKey
            let endDay = isCurrentMonth ? referenceDay : daysInThisMonth
            let days1 = max(0, endDay - startDay + 1)
            isFirstMonth = false

            let started2 = ym >= file2StartMonth
            var days2 = 0
            if started2 {
                days2 = ym == file2StartMonth
                    ? max(0, endDay - file2StartDay + 1)
                    : max(0, endDay - 1 + 1)
            }

            let rate1 = rates1[ym] ?? rates1[endMonthKey] ?? 0
            let rate2 = rates2[ym] ?? rates2[endMonthKey] ?? 0
            interest1 += principal1 * (rate1 / 100 / 30) * Double(days1)
            if started2 { interest2 += principal2 * (rate2 / 100 / 30) * Double(days2) }

            var paidThisMonth = 0.0

            for payment in salaryByMonth[ym] ?? [] {
                var amount = payment.amount
                paidThisMonth += amount
                let usedForInterest = min(amount, max(0, interest1))
                interest1 -= usedForInterest
                amount -= usedForInterest
                principal1 -= amount
            }
            for payment in (fibaByMonth[ym] ?? []).filter(\.file1Only) {
                var amount = payment.amount
                paidThisMonth += amount
                let usedForInterest = min(amount, max(0, interest1))
                interest1 -= usedForInterest
                amount -= usedForInterest
                principal1 -= amount
            }

            var undesignated = 0.0
            undesignated += (takasByMonth[ym] ?? []).reduce(0) { $0 + $1.amount }
            undesignated += (fibaByMonth[ym] ?? []).filter { !$0.file1Only }.reduce(0) { $0 + $1.amount }
            if undesignated > 0 {
                paidThisMonth += undesignated
                var remaining = undesignated

                let usedForInterest1 = min(remaining, max(0, interest1))
                interest1 -= usedForInterest1
                remaining -= usedForInterest1

                let usedForPrincipal1 = min(remaining, max(0, principal1))
                principal1 -= usedForPrincipal1
                remaining -= usedForPrincipal1

                if remaining > 0 {
                    let usedForInterest2 = min(remaining, max(0, interest2))
                    interest2 -= usedForInterest2
                    remaining -= usedForInterest2

                    let usedForPrincipal2 = min(remaining, max(0, principal2))
                    principal2 -= usedForPrincipal2
                    remaining -= usedForPrincipal2

                    if remaining > 0 { principal2 -= remaining }
                }
            }

            let balance1 = principal1 + interest1
            let balance2 = started2 ? principal2 + interest2 : nil
            rows.append(CombinedLedgerRow(
                month: ym,
                file1Rate: rate1,
                file1Balance: balance1,
                file2Rate: started2 ? rate2 : nil,
                file2Balance: balance2,
                paidThisMonth: paidThisMonth,
                totalBalance: balance1 + (balance2 ?? 0)
            ))

            month += 1
            if month > 12 { month = 1; year += 1 }
        }

        return rows
    }

    // MARK: - Running a scenario

    public static func run(scenario: DebtScenario) -> SimulationResult {
        let totalPaid = totalOfAllPayments

        guard scenario.hasMonthlyBreakdown else {
            // No monthly breakdown exists for the bank's own figure, so the
            // uncredited total (TAKAS + every Fibabanka transfer) is applied as
            // one lump sum, in priority order: file 1's official balance first,
            // any remainder spilling into file 2's.
            let file1Total = file1Principal + file1OfficialInterest + file1Charges
            let file2Total = file2Principal + file2OfficialInterest + file2Charges
            var file1Balance = file1Total - file1CreditedPayments
            var file2Balance = file2Total

            let extra = takasDeductions.reduce(0) { $0 + $1.amount } + fibabankaTransfers.reduce(0) { $0 + $1.amount }
            let usedByFile1 = min(extra, max(0, file1Balance))
            file1Balance -= usedByFile1
            file2Balance -= (extra - usedByFile1)

            return SimulationResult(file1Balance: file1Balance, file2Balance: file2Balance, totalPaid: totalPaid, rows: [])
        }

        let rates1: [String: Double]
        let rates2: [String: Double]
        switch scenario {
        case .ceiling:
            rates1 = kmhRates
            rates2 = cardRates
        case .flat, .official:
            let allMonths = months(from: file1StartMonth, to: currentMonth)
            rates1 = Dictionary(uniqueKeysWithValues: allMonths.map { ($0, file1FlatRate) })
            rates2 = Dictionary(uniqueKeysWithValues: allMonths.map { ($0, file2FlatRate) })
        }

        let rows = buildWaterfallLedger(rates1: rates1, rates2: rates2)
        let last = rows.last

        return SimulationResult(
            file1Balance: (last?.file1Balance ?? 0) + file1Charges,
            file2Balance: (last?.file2Balance ?? 0) + file2Charges,
            totalPaid: totalPaid,
            rows: rows
        )
    }

    public static let methodologyNote = """
    Yöntem (04.08.2026 web araştırması ile doğrulandı): icra faizi gün esaslı, basit faiz olarak \
    hesaplanır — bileşik faiz uygulanmaz; ay bazında değil, o aydaki gerçek gün sayısınca (aylık \
    oran/30 × gün) kalan anapara üzerinden işler. Kısmi ödemeler TBK m.100 sırasına göre önce \
    birikmiş faize, sonra anaparaya mahsup edilir; masraf/vekâlet/BSMV/KKDF/harç bankanın resmî \
    rakamıyla sabit tutulup sonuca bir kez eklenir (grafiğe dahil değil, çünkü tek tek tahsilat \
    bazında kaç TL harç kesildiği ayrı ayrı belgeyle doğrulanamadı). "Banka Resmi Rakamı" \
    senaryosunda günlük kırılım yok.
    """

    /// Fixed by law rather than by a slider — see the module doc comment for
    /// the three rules this encodes.
    public static let mahsupPriorityNote = """
    Mahsup önceliği (artık slider değil, kanun uygulanıyor): Maaş haczi → %100 Dosya1 (İİK — birden \
    fazla haciz "sıra" usulü: işverene ilk ulaşan haciz, o borç tamamen bitene kadar tek başına \
    kesinti alır). Fibabanka'da açıkça "ek hesap borcu" yazan 2 ödeme → %100 Dosya1 (TBK m.101 — \
    borçlunun kendi tayini). TAKAS (26 kalem, dosya belirtilmemiş) ve "ek hesap ve kredi kartı" \
    yazan belirsiz Fibabanka ödemeleri (5 kalem) → önce Dosya1'e (TBK m.102 — açıklama yoksa ödeme \
    ilk takip edilen borca mahsup edilir; 162868 takibi 15.08.2024, 234554 takibi 14.10.2024'ten \
    önce başladı), Dosya1 tamamen kapanınca kalan Dosya2'ye taşar. Kaynak: maaş haczi sıra usulü \
    (gezicihukuk.net), TBK m.101, TBK m.102 (04.08.2026 doğrulandı).
    """
}
