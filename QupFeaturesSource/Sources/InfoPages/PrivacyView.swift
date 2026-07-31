import SwiftUI
import DesignSystem
import ComponentSystem

/// Apple-style Privacy marketing page: a dark full-bleed hero, an oversized
/// commitment statement, a grid of tall full-bleed feature tiles, a row of
/// learn-more topics, and a transparency/control footer.
///
/// All copy is placeholder text and lives in `PrivacyContent` (each string is
/// marked `// TODO`). Section spacing follows Apple's generous rhythm via
/// `PrivacyMetrics`; the hero and feature tiles are full-bleed.
public struct PrivacyView: View {
    public init() {}

    @Environment(\.eqColors) private var colors
    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let padding = LayoutMetrics.pagePadding(for: width)
            let sectionGap = PrivacyMetrics.sectionGap(for: width)

            ScrollView {
                VStack(spacing: 0) {
                    // Full-bleed dark hero.
                    PrivacyHero(
                        eyebrowSymbol: PrivacyContent.heroSymbol,
                        title: PrivacyContent.heroTitle,
                        statement: PrivacyContent.heroStatement,
                        actionTitle: PrivacyContent.heroActionTitle,
                        action: { /* TODO: play privacy film */ }
                    )

                    // Centered marketing body with Apple-scale section spacing.
                    VStack(alignment: .leading, spacing: sectionGap) {
                        commitmentSection
                        featuresSection(width: width)
                        learnMoreSection
                        transparencySection
                    }
                    .frame(maxWidth: PrivacyMetrics.bodyMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, padding)
                    .padding(.top, sectionGap)
                    .padding(.bottom, sectionGap)
                }
            }
            #if os(macOS)
            .scrollIndicators(.automatic)
            #else
            .scrollIndicators(.hidden)
            #endif
            .background(colors.bg)
        }
        .navigationTitle("Privacy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Sections

    private var commitmentSection: some View {
        PrivacyStatementBand(
            title: PrivacyContent.commitmentTitle,
            message: PrivacyContent.commitmentBody
        )
    }

    private func featuresSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: EQSpacing.xxxl) {
            Text(PrivacyContent.featuresTitle)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(colors.fg)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            PrivacyFeatureGrid(
                pillars: PrivacyContent.pillars,
                tileHeight: PrivacyMetrics.tileHeight(for: width)
            ) { _ in
                // TODO: route to the matching feature detail.
            }
        }
    }

    private var learnMoreSection: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xl) {
            Text(PrivacyContent.learnMoreTitle)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(colors.fg)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 320), spacing: EQSpacing.md)],
                spacing: EQSpacing.md
            ) {
                ForEach(PrivacyContent.topics) { topic in
                    PrivacyTopicTile(topic: topic) {
                        // TODO: open the topic detail.
                    }
                }
            }
        }
    }

    private var transparencySection: some View {
        EQCard(padding: EQSpacing.xxl) {
            VStack(alignment: .leading, spacing: EQSpacing.lg) {
                EQSectionHeader(
                    title: PrivacyContent.transparencyTitle,
                    subtitle: PrivacyContent.transparencyBody,
                    systemImage: "checkmark.shield.fill"
                )
                EQAdaptiveStack(spacing: EQSpacing.md) {
                    EQPrimaryButton(PrivacyContent.transparencyPrimaryTitle, expands: false) {
                        // TODO: open privacy management.
                    }
                    EQSecondaryButton(PrivacyContent.transparencySecondaryTitle) {
                        // TODO: open privacy policy.
                    }
                }
            }
        }
    }
}

