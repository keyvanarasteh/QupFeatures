import Foundation

/// The seven claim items plus the credited payment, for one enforcement file.
public struct EnforcementFileInputs: Equatable, Sendable {
    public var principal: Double
    public var interest: Double
    public var attorney: Double
    public var cost: Double
    public var bsmv: Double
    public var kkdf: Double
    public var harc: Double
    /// "Yatan Para" — what the official file records as received.
    public var paid: Double

    public init(
        principal: Double,
        interest: Double,
        attorney: Double,
        cost: Double,
        bsmv: Double,
        kkdf: Double,
        harc: Double,
        paid: Double
    ) {
        self.principal = principal
        self.interest = interest
        self.attorney = attorney
        self.cost = cost
        self.bsmv = bsmv
        self.kkdf = kkdf
        self.harc = harc
        self.paid = paid
    }

    /// Dosya Toplam Alacağı.
    public var totalClaim: Double {
        principal + interest + attorney + cost + bsmv + kkdf + harc
    }

    /// Resmî Dosya Bakiyesi — claim less only what the file credits.
    public var officialBalance: Double {
        totalClaim - paid
    }
}

/// Payments proven by statement or receipt that never reached either file.
public struct UncreditedPaymentInputs: Equatable, Sendable {
    /// İş Bankası "TAKAS YOLUYLA TAKİP BORCU TAHSİLATI" deductions.
    public var takas: Double
    /// FAST transfers from Fibabanka to the attorney's personal account.
    public var fiba: Double

    public init(takas: Double, fiba: Double) {
        self.takas = takas
        self.fiba = fiba
    }

    public var total: Double { takas + fiba }
}

/// Everything the page computes, from the editable amounts.
///
/// The whole point of the sheet: the official balance counts only payments the
/// file recorded, so it overstates the debt by every proven-but-uncredited lira.
public struct DebtCalculation: Equatable, Sendable {
    public var file1: EnforcementFileInputs
    public var file2: EnforcementFileInputs
    public var uncredited: UncreditedPaymentInputs

    public init(
        file1: EnforcementFileInputs,
        file2: EnforcementFileInputs,
        uncredited: UncreditedPaymentInputs
    ) {
        self.file1 = file1
        self.file2 = file2
        self.uncredited = uncredited
    }

    public static let `default` = DebtCalculation(
        file1: EnforcementFileInputs(
            principal: 255_411.49,
            interest: 241_505.75,
            attorney: 40_865.84,
            cost: 673.40,
            bsmv: 12_075.29,
            kkdf: 12_075.29,
            harc: 11_621.25,
            paid: 300_118.55
        ),
        file2: EnforcementFileInputs(
            principal: 131_673.68,
            interest: 102_250.06,
            attorney: 21_067.79,
            cost: 673.40,
            bsmv: 5_112.50,
            kkdf: 5_112.50,
            harc: 11_982.30,
            paid: 0
        ),
        uncredited: UncreditedPaymentInputs(
            takas: 164_687.12,
            fiba: 140_000.00
        )
    )

    /// İki Dosya Toplam Alacak.
    public var totalClaim: Double {
        file1.totalClaim + file2.totalClaim
    }

    /// Resmî Kalan Bakiye — what the files say is still owed.
    public var officialBalance: Double {
        file1.officialBalance + file2.officialBalance
    }

    /// Toplam Belgeli Ödeme — every channel, credited or not.
    public var totalPaid: Double {
        file1.paid + file2.paid + uncredited.total
    }

    /// GERÇEK KALAN BORÇ.
    public var realBalance: Double {
        totalClaim - totalPaid
    }

    /// How much the official balance overstates the debt — equal to the
    /// uncredited total, and restated here because that equality is the claim
    /// being made rather than an identity to take on faith.
    public var difference: Double {
        officialBalance - realBalance
    }
}
