import DesignSystem
import SwiftUI

/// An editable Turkish-lira amount.
///
/// Keeps its own text buffer so a half-typed value isn't reformatted under the
/// caret; the grouped form is restored when the field loses focus, matching the
/// source page's blur behaviour. The buffer also follows `value` when it changes
/// from outside — which is what makes "reset to defaults" visible in the fields.
struct AmountField: View {
    @Environment(\.cupertinoColors) private var colors

    @Binding var value: Double
    var accessibilityLabel: String

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("0,00", text: $text)
            .textFieldStyle(.plain)
            .font(Theme.Typography.code)
            .foregroundStyle(colors.fg)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            #if os(iOS)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()
            #endif
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: 160)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(colors.inputBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(isFocused ? colors.primary : colors.subtleBorder, lineWidth: 1)
            )
            .accessibilityLabel(accessibilityLabel)
            .onAppear { text = TurkishLira.plain(value) }
            .onChange(of: text) { _, newValue in
                let parsed = TurkishLira.parse(newValue)
                if parsed != value { value = parsed }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = TurkishLira.plain(value) }
            }
            .onChange(of: value) { _, newValue in
                // Only when the change came from elsewhere (reset), or typing
                // would fight the caret.
                if !isFocused, TurkishLira.parse(text) != newValue {
                    text = TurkishLira.plain(newValue)
                }
            }
    }
}

/// Label on the left, editable amount on the right.
struct AmountRow: View {
    @Environment(\.cupertinoColors) private var colors

    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(colors.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            AmountField(value: $value, accessibilityLabel: title)
        }
    }
}

/// Label on the left, computed amount on the right.
struct ComputedRow: View {
    @Environment(\.cupertinoColors) private var colors

    let title: String
    let value: Double
    var emphasis: Emphasis = .subtotal

    enum Emphasis {
        case subtotal
        case result
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(title)
                .font(emphasis == .result ? Theme.Typography.bodyEmphasized : Theme.Typography.subheadline)
                .foregroundStyle(colors.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(TurkishLira.formatted(value))
                .font(Theme.Typography.code)
                .fontWeight(emphasis == .result ? .bold : .semibold)
                .foregroundStyle(emphasis == .result ? colors.primary : colors.fg)
        }
        .padding(.top, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Sourcing note under a section — the provenance the page is built on.
struct SourceNote: View {
    @Environment(\.cupertinoColors) private var colors

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .foregroundStyle(colors.mutedFg)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A monospaced block for the formula overview.
struct FormulaBlock: View {
    @Environment(\.cupertinoColors) private var colors

    let text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(Theme.Typography.code)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: true, vertical: true)
                .padding(Theme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(colors.codeBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(colors.codeBorder, lineWidth: 1)
        )
    }
}

/// The warning banner carried over from the source page.
struct DisclaimerBanner: View {
    @Environment(\.cupertinoColors) private var colors

    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(colors.warning)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(colors.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(colors.warning.opacity(0.5), lineWidth: 1)
        )
    }
}

/// One headline number in the stat grid.
struct StatTile: View {
    @Environment(\.cupertinoColors) private var colors

    let title: String
    let value: Double
    var tone: StatusTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
            Text(TurkishLira.formatted(value))
                .font(Theme.Typography.code)
                .fontWeight(.bold)
                .foregroundStyle(tone == .neutral ? colors.fg : tone.color(in: colors))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
