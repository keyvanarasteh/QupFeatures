import SwiftUI
import DesignSystem
import ComponentSystem
import DynamicUI
import QlineAuth

/// About page — ported from 11Q's `Features/About/AboutView.swift`.
/// 11Q's "My Research" tab (and its `AppRouter` section binding) is not ported;
/// that surface belongs to a future Research feature port.
///
/// Native chrome (hero, version) stays in SwiftUI. Tenant/org copy is a
/// **DynamicUI host** (`DynamicHostView`) so Theme branding and menus share one engine.
public struct AboutView: View {
    @Environment(\.eqColors) private var colors
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init() {}

    public var body: some View {
        aboutContent
            .background(colors.bg)
            .navigationTitle("About")
            #if os(iOS)
            .navigationBarTitleDisplayMode(sizeClass == .compact ? .large : .inline)
            #endif
    }

    private var aboutContent: some View {
        EQPageContainer {
            VStack(alignment: .leading, spacing: EQSpacing.xxl) {
                EQSectionHeader(
                    title: "About Cupertino",
                    subtitle: "A multiplatform companion built with SwiftUI for iOS and macOS.",
                    systemImage: "sparkles"
                )

                heroCard

                EQAdaptiveStack(spacing: EQSpacing.lg) {
                    featureCard(
                        title: "Adaptive by design",
                        body: loremShort,
                        icon: "rectangle.split.2x1"
                    )
                    featureCard(
                        title: "Secure sessions",
                        body: "Sign in with the same qline.tech auth used by MarketQOS — including 2FA, OAuth, and password recovery.",
                        icon: "lock.shield"
                    )
                }

                EQCard {
                    VStack(alignment: .leading, spacing: EQSpacing.md) {
                        Text("Our story")
                            .font(.headline)
                            .foregroundStyle(colors.fg)
                        Text(loremLong)
                            .font(.body)
                            .foregroundStyle(colors.cardFg)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(loremMedium)
                            .font(.body)
                            .foregroundStyle(colors.mutedFg)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Multi-host SDUI region (Theme / tenant About / CMS later).
                DynamicHostView(
                    json: OrgAboutDynamicFixture.json,
                    embedStyle: .plain,
                    installExtensions: InfoDynamicHost.installExtensions
                )
                .frame(minHeight: 220)

                EQCard {
                    VStack(alignment: .leading, spacing: EQSpacing.sm) {
                        Label("Version", systemImage: "tag")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colors.fg)
                        Text(versionLabel)
                            .font(.body)
                            .foregroundStyle(colors.mutedFg)
                        Text("API host: \(AuthConfig.displayAPIHost)")
                            .font(.caption)
                            .foregroundStyle(colors.mutedFg)
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        EQCard(padding: EQSpacing.xxl) {
            EQAdaptiveStack(verticalAlignment: .center, spacing: EQSpacing.xl) {
                RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous)
                    .fill(colors.primary.opacity(0.14))
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: "app.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(colors.primary)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Built for Apple platforms")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.fg)
                    Text(loremMedium)
                        .font(.subheadline)
                        .foregroundStyle(colors.mutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func featureCard(title: String, body: String, icon: String) -> some View {
        EQCard {
            VStack(alignment: .leading, spacing: EQSpacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(colors.primary)
                    .frame(width: 36, height: 36)
                    .background(colors.primarySoft, in: RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(colors.fg)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(colors.mutedFg)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // Placeholder copy
    private let loremShort = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer posuere erat a ante venenatis dapibus."
    private let loremMedium = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation."
    private let loremLong = """
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus lacinia odio vitae vestibulum vestibulum. \
    Cras venenatis euismod malesuada. Nulla facilisi. Donec non magna sed urna elementum fringilla. \
    Phasellus ac massa at lectus facilisis tristique. Integer at libero non elit tincidunt auctor.
    """
}
