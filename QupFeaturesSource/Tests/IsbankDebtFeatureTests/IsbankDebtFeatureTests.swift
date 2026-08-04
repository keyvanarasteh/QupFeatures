import Testing
@testable import IsbankDebtFeature

@Suite("Turkish lira parsing")
struct TurkishLiraTests {
    /// The whole calculation rests on this: read as C-locale, "255.411,49"
    /// becomes 255.411 and the file loses a quarter-million lira.
    @Test func parsesGroupedTurkishAmounts() {
        #expect(TurkishLira.parse("255.411,49") == 255_411.49)
        #expect(TurkishLira.parse("1.164.687,12") == 1_164_687.12)
        #expect(TurkishLira.parse("673,40") == 673.40)
        #expect(TurkishLira.parse("0,00") == 0)
    }

    @Test func toleratesPartialInput() {
        #expect(TurkishLira.parse("") == 0)
        #expect(TurkishLira.parse("   ") == 0)
        #expect(TurkishLira.parse("12,") == 12)
        #expect(TurkishLira.parse("abc") == 0)
    }

    @Test func roundTripsThroughDisplayForm() {
        for value in [0.0, 673.40, 255_411.49, 1_164_687.12] {
            #expect(TurkishLira.parse(TurkishLira.plain(value)) == value)
        }
    }
}

@Suite("Debt calculation")
struct DebtCalculationTests {
    private let calculation = DebtCalculation.default

    /// Summing seven decimal amounts lands a hair off the printed figure
    /// (574228.3099999999), so compare to within half a kuruş rather than
    /// asserting binary equality on money.
    private func isKurus(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 0.005
    }

    @Test func totalsMatchTheOfficialFileAccounts() {
        // Dosya Hesabı 162868 and 234554, summed item by item.
        #expect(isKurus(calculation.file1.totalClaim, 574_228.31))
        #expect(isKurus(calculation.file2.totalClaim, 277_872.23))
        #expect(isKurus(calculation.totalClaim, 852_100.54))
    }

    /// 551.981,99 TL is the figure the source page quotes as the official
    /// balance, so this pins the port against it.
    @Test func officialBalanceCountsOnlyCreditedPayments() {
        #expect(isKurus(calculation.file1.officialBalance, 274_109.76))
        #expect(isKurus(calculation.file2.officialBalance, 277_872.23))
        #expect(isKurus(calculation.officialBalance, 551_981.99))
    }

    @Test func realBalanceAlsoCountsDocumentedPayments() {
        #expect(isKurus(calculation.uncredited.total, 304_687.12))
        #expect(isKurus(calculation.totalPaid, 604_805.67))
        #expect(isKurus(calculation.realBalance, 247_294.87))
    }

    /// The page's central claim: the official balance is overstated by exactly
    /// the payments the files never recorded.
    @Test func differenceEqualsTheUncreditedTotal() {
        #expect(isKurus(calculation.difference, calculation.uncredited.total))
    }

    @Test func editingAnAmountMovesTheRealBalance() {
        var edited = calculation
        edited.uncredited.fiba += 10_000
        #expect(isKurus(edited.realBalance, calculation.realBalance - 10_000))
        #expect(isKurus(edited.officialBalance, calculation.officialBalance))
    }
}
