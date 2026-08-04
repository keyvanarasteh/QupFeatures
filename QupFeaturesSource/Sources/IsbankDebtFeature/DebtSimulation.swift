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
        case .ceiling: "TCMB Tavanı (Azami Yasal)"
        case .flat: "Hiç İndirilmediyse"
        }
    }

    public var assumption: String {
        switch self {
        case .official:
            "Bankanın Dosya Hesabı'nda beyan ettiği toplam faiz (241.505,75 + 102.250,06 TL) sabit kullanılır; aylık kırılım yok."
        case .ceiling:
            "Her ay TCMB'nin doğrulanmış azami (tavan) gecikme faiz oranı, kalan anapara üzerinden basit (bileşik olmayan) faiz olarak uygulanır — bankanın uygulayabileceği en yüksek yasal senaryo."
        case .flat:
            "Takip başlangıcındaki oran (%5,30 / %4,55) hiç düşürülmeden, Ağustos 2026'ya kadar sabit uygulanmış varsayılır — banka tavanı hiç indirmediyse ortaya çıkacak en kötümser senaryo."
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

/// One simulated month for one file.
public struct LedgerEntry: Identifiable, Equatable, Sendable {
    public var id: String { month }
    public let month: String
    public let rate: Double
    public let interest: Double
    public let paid: Double
    /// Remaining principal plus unpaid accrued interest. Goes negative once the
    /// payments overtake the debt.
    public let balance: Double
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

/// The outcome of one scenario at one split setting.
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
/// breakdown, so the only way to test it is to re-run the arithmetic: simple
/// interest on the outstanding principal each month, payments applied to
/// accrued interest before principal (TBK m.100), across every documented
/// payment channel rather than only the ones the file credited.
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

    // MARK: - Splitting shared payments

    /// Payments per month for one file, given how much of the shared money is
    /// attributed to file 1.
    ///
    /// Takas and the "ek hesap ve kredi kartı" transfers name both debts, so
    /// there is no document that settles the split — hence the slider.
    static func paymentsByMonth(forFile file: Int, file1Share: Double) -> [String: Double] {
        let share = file == 1 ? file1Share : 1 - file1Share
        var result: [String: Double] = [:]

        if file == 1 {
            for payment in salaryGarnishments {
                result[payment.month, default: 0] += payment.amount
            }
        }
        for payment in takasDeductions {
            result[payment.month, default: 0] += payment.amount * share
        }
        for payment in fibabankaTransfers {
            if payment.file1Only {
                if file == 1 { result[payment.month, default: 0] += payment.amount }
            } else {
                result[payment.month, default: 0] += payment.amount * share
            }
        }
        return result
    }

    /// Shared payments attributed to one file — the official scenario needs the
    /// total without running a ledger.
    static func sharedPaymentTotal(forFile file: Int, file1Share: Double) -> Double {
        let share = file == 1 ? file1Share : 1 - file1Share
        var total = takasDeductions.reduce(0) { $0 + $1.amount * share }
        for payment in fibabankaTransfers {
            if payment.file1Only {
                if file == 1 { total += payment.amount }
            } else {
                total += payment.amount * share
            }
        }
        return total
    }

    // MARK: - The ledger

    /// Simple interest on the outstanding principal — not compounded — with each
    /// payment clearing accrued interest before it touches principal.
    static func ledger(
        startAmount: Double,
        startMonth: String,
        rates: [String: Double],
        payments: [String: Double]
    ) -> [LedgerEntry] {
        let timeline = months(from: startMonth, to: currentMonth)
        var principal = startAmount
        var accruedInterest: Double = 0
        var entries: [LedgerEntry] = []

        for month in timeline {
            let rate = rates[month] ?? rates[timeline.last ?? month] ?? 0
            let interest = principal * (rate / 100)
            accruedInterest += interest

            let paid = payments[month] ?? 0
            let fromInterest = min(paid, accruedInterest)
            accruedInterest -= fromInterest
            principal -= (paid - fromInterest)

            entries.append(LedgerEntry(
                month: month,
                rate: rate,
                interest: interest,
                paid: paid,
                balance: principal + accruedInterest
            ))
        }
        return entries
    }

    // MARK: - Running a scenario

    /// - Parameter file1Share: 0…1, the fraction of shared payments credited to
    ///   file 1 (the slider).
    public static func run(scenario: DebtScenario, file1Share: Double) -> SimulationResult {
        let totalPaid = totalOfAllPayments

        guard scenario.hasMonthlyBreakdown else {
            // No monthly breakdown exists for the bank's own figure, so the
            // best that can be done is subtract every documented payment from
            // its declared total.
            let file1Total = file1Principal + file1OfficialInterest + file1Charges
            let file2Total = file2Principal + file2OfficialInterest + file2Charges
            return SimulationResult(
                file1Balance: file1Total - (file1CreditedPayments + sharedPaymentTotal(forFile: 1, file1Share: file1Share)),
                file2Balance: file2Total - sharedPaymentTotal(forFile: 2, file1Share: file1Share),
                totalPaid: totalPaid,
                rows: []
            )
        }

        let allMonths = months(from: file1StartMonth, to: currentMonth)
        let file1Rates: [String: Double]
        let file2Rates: [String: Double]
        switch scenario {
        case .ceiling:
            file1Rates = kmhRates
            file2Rates = cardRates
        case .flat, .official:
            file1Rates = Dictionary(uniqueKeysWithValues: allMonths.map { ($0, file1FlatRate) })
            file2Rates = Dictionary(uniqueKeysWithValues: allMonths.map { ($0, file2FlatRate) })
        }

        let ledger1 = ledger(
            startAmount: file1Principal,
            startMonth: file1StartMonth,
            rates: file1Rates,
            payments: paymentsByMonth(forFile: 1, file1Share: file1Share)
        )
        let ledger2 = ledger(
            startAmount: file2Principal,
            startMonth: file2StartMonth,
            rates: file2Rates,
            payments: paymentsByMonth(forFile: 2, file1Share: file1Share)
        )

        let file2ByMonth = Dictionary(uniqueKeysWithValues: ledger2.map { ($0.month, $0) })
        let rows = ledger1.map { entry -> CombinedLedgerRow in
            let second = file2ByMonth[entry.month]
            return CombinedLedgerRow(
                month: entry.month,
                file1Rate: entry.rate,
                file1Balance: entry.balance,
                file2Rate: second?.rate,
                file2Balance: second?.balance,
                paidThisMonth: entry.paid + (second?.paid ?? 0),
                totalBalance: entry.balance + (second?.balance ?? 0)
            )
        }

        return SimulationResult(
            file1Balance: (ledger1.last?.balance ?? 0) + file1Charges,
            file2Balance: (ledger2.last?.balance ?? 0) + file2Charges,
            totalPaid: totalPaid,
            rows: rows
        )
    }

    public static let methodologyNote = """
    Basit faiz: her ay yalnızca kalan anapara üzerinden hesaplanır (bileşik değil); ödemeler önce birikmiş \
    faize, sonra anaparaya mahsup edilir (TBK m.100). Vekâlet/masraf/BSMV/KKDF/harç bankanın resmî rakamıyla \
    sabit tutulup sonuca bir kez eklenir (grafiğe dahil değil). "Banka Resmi Rakamı" senaryosunda aylık \
    kırılım yok.
    """

    public static let splitExplanation = "TAKAS + karışık Fibabanka ödemelerinin Dosya1'e (KMH) payı"
}
