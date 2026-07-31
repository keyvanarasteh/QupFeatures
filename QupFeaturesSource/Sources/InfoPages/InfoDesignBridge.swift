import SwiftUI
import DesignSystem
import ComponentSystem

// Ported from 11Q following the same bridge pattern as
// `CrawlerUx/Design/CrawlerDesignBridge.swift`: `CupertinoColors`' field names
// match 11Q's `EQColors` field-for-field, so the ported views need zero
// call-site changes for colors/spacing/radius.

typealias EQSpacing = Theme.Spacing
typealias EQRadius = Theme.Radius
typealias EQColors = CupertinoColors

extension EnvironmentValues {
    var eqColors: CupertinoColors { cupertinoColors }
}

/// Adaptive layout helpers, scoped to this package (mirrors 11Q `LayoutMetrics`).
enum LayoutMetrics {
    static let regularContentMaxWidth: CGFloat = 720
    static let contentMaxWidthWide: CGFloat = 1280

    static func pagePadding(for width: CGFloat) -> CGFloat {
        if width < 400 { return EQSpacing.lg }
        if width < 700 { return EQSpacing.xl }
        return EQSpacing.xxxl
    }
}

/// Stacks horizontally when space allows, otherwise vertically.
struct EQAdaptiveStack<Content: View>: View {
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat = EQSpacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: verticalAlignment, spacing: spacing, content: content)
            VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
        }
    }
}

struct EQPageContainer<Content: View>: View {
    @Environment(\.eqColors) private var colors
    var maxWidth: CGFloat = LayoutMetrics.regularContentMaxWidth
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let padding = LayoutMetrics.pagePadding(for: geo.size.width)
            ScrollView {
                content()
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, padding)
                    .padding(.vertical, EQSpacing.xxl)
            }
            #if os(macOS)
            .scrollIndicators(.automatic)
            #else
            .scrollIndicators(.hidden)
            #endif
            .background(colors.bg)
        }
    }
}
