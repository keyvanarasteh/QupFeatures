import SwiftUI
import DesignSystem
import ComponentSystem
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Privacy components (Apple-style)
//
// Reusable building blocks for the Privacy page, styled after apple.com/privacy:
// a dark full-bleed hero, oversized statement bands, tall full-bleed feature
// tiles whose image fills the whole card, and compact topic tiles. Copy is
// supplied by the caller so it can be swapped later (see PrivacyContent —
// every string there is marked `// TODO`).

/// Spacing rhythm for the marketing page. Apple's Privacy page separates major
/// sections with far more air than a typical app screen; these constants scale
/// that generous rhythm to the available content width.
enum PrivacyMetrics {
    /// Vertical gap between major sections.
    static func sectionGap(for width: CGFloat) -> CGFloat {
        width < 700 ? 72 : width < 1100 ? 104 : 128
    }

    /// Top/bottom padding of the dark hero.
    static func heroPadding(for width: CGFloat) -> CGFloat {
        width < 700 ? 88 : 132
    }

    /// Body content max width (text sections). Image sections go full-bleed.
    static let bodyMaxWidth: CGFloat = 1040
    /// Height of a tall portrait feature tile.
    static func tileHeight(for width: CGFloat) -> CGFloat {
        width < 700 ? 460 : 520
    }
    /// Generous corner radius used on the large tiles.
    static let tileRadius: CGFloat = 28
}

/// Fills its frame with an asset image when `imageName` resolves in the asset
/// catalog, otherwise falls back to a diagonal gradient with a large glyph.
/// This lets the layout ship now and adopt real photography later — just set
/// `imageName` on the content model.
struct PrivacyImageSlot: View {
    let imageName: String?
    let systemImage: String
    let accent: [Color]

    var body: some View {
        ZStack {
            if let imageName, Self.assetExists(imageName) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: accent, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Cross-platform check so a missing asset degrades to the gradient instead
    /// of rendering an empty image.
    private static func assetExists(_ name: String) -> Bool {
        #if os(macOS)
        return NSImage(named: name) != nil
        #elseif os(iOS)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

/// Full-bleed dark hero: lock glyph, oversized centered headline, optional
/// supporting statement, and a text "watch the film"–style action link.
/// Always renders dark (black canvas / white text) to match Apple's hero,
/// independent of the app's light/dark theme.
struct PrivacyHero: View {
    let eyebrowSymbol: String
    let title: String
    let statement: String?
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: EQSpacing.xl) {
                Image(systemName: eyebrowSymbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: geo.size.width < 700 ? 40 : 56, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let statement {
                    Text(statement)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 700)
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 6) {
                            Text(actionTitle)
                            Image(systemName: "play.circle.fill")
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(Color(hex: 0x2997FF))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, EQSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, EQSpacing.xl)
            .padding(.vertical, PrivacyMetrics.heroPadding(for: geo.size.width))
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private var heroHeight: CGFloat {
        statement == nil ? 360 : 520
    }
}

/// Oversized headline + supporting paragraph, centered on the page background.
/// Mirrors Apple's "We're committed to protecting your data." band.
struct PrivacyStatementBand: View {
    @Environment(\.eqColors) private var colors
    let title: String
    let message: String
    var alignment: TextAlignment = .leading

    var body: some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: EQSpacing.lg) {
            Text(title)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(colors.fg)
                .multilineTextAlignment(alignment)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.system(size: 19))
                .foregroundStyle(colors.mutedFg)
                .multilineTextAlignment(alignment)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760, alignment: alignment == .center ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

/// A tall, full-bleed feature tile: the image (or gradient fallback) fills the
/// whole card, a short stacked title sits over a bottom scrim, and a "+" button
/// expands the longer copy in place — mirroring Apple's privacy feature tiles.
struct PrivacyFeatureTile: View {
    @Environment(\.eqColors) private var colors
    let pillar: PrivacyPillar
    var height: CGFloat = 520
    var onLink: (() -> Void)? = nil

    @State private var expanded = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PrivacyImageSlot(
                imageName: pillar.imageName,
                systemImage: pillar.systemImage,
                accent: pillar.accent
            )

            // Bottom scrim so white text stays legible over any image.
            LinearGradient(
                colors: [.clear, .black.opacity(expanded ? 0.86 : 0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: EQSpacing.md) {
                Text(pillar.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if expanded {
                    Text(pillar.summary)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    if let linkTitle = pillar.linkTitle {
                        Button {
                            onLink?()
                        } label: {
                            HStack(spacing: 4) {
                                Text(linkTitle)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(hex: 0x2997FF))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(EQSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Expand / collapse control, top-trailing like Apple's "+".
            Button {
                withAnimation(.snappy(duration: 0.28)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "minus" : "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.35), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(EQSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .accessibilityLabel(expanded ? "Collapse \(plainTitle)" : "Expand \(plainTitle)")
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: PrivacyMetrics.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PrivacyMetrics.tileRadius, style: .continuous)
                .stroke(colors.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var plainTitle: String {
        pillar.title.replacingOccurrences(of: "\n", with: " ")
    }
}

/// Adaptive grid of tall feature tiles — 1 column on phone, 2 on wide layouts,
/// with generous gutters so each image reads as its own large surface.
struct PrivacyFeatureGrid: View {
    let pillars: [PrivacyPillar]
    var tileHeight: CGFloat = 520
    var onSelect: ((PrivacyPillar) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: EQSpacing.xl)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: EQSpacing.xl) {
            ForEach(pillars) { pillar in
                PrivacyFeatureTile(pillar: pillar, height: tileHeight) {
                    onSelect?(pillar)
                }
            }
        }
    }
}

/// Compact tile used in the "learn more" topic row: symbol, title, one-line caption.
struct PrivacyTopicTile: View {
    @Environment(\.eqColors) private var colors
    let topic: PrivacyTopic
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: EQSpacing.md) {
                Image(systemName: topic.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colors.primary)
                    .frame(width: 40, height: 40)
                    .background(colors.primarySoft, in: RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.fg)
                    Text(topic.caption)
                        .font(.system(size: 14))
                        .foregroundStyle(colors.mutedFg)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.mutedFg)
            }
            .padding(EQSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(colors.card, in: RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous)
                .stroke(colors.border.opacity(0.9), lineWidth: 1)
        )
    }
}
