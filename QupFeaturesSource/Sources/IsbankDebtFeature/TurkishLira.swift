import Foundation

/// Turkish-format money parsing and display: `.` groups thousands, `,` is the
/// decimal separator — the inverse of the C locale, so a plain `Double(_:)`
/// would read "255.411,49" as 255.411 and silently lose six figures.
public enum TurkishLira {
    private static let locale = Locale(identifier: "tr_TR")

    private static let display: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Reads a user-typed amount. Tolerant on purpose: the field is edited by
    /// hand, so half-typed values like "12." or "1.2" have to round-trip
    /// without the total jumping to zero mid-keystroke.
    public static func parse(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let normalized = trimmed
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        return Double(normalized) ?? 0
    }

    /// Grouped amount without a unit — what an editable field shows.
    public static func plain(_ value: Double) -> String {
        display.string(from: NSNumber(value: value)) ?? "0,00"
    }

    /// Grouped amount with the unit — what a computed total shows.
    public static func formatted(_ value: Double) -> String {
        plain(value) + " TL"
    }
}
