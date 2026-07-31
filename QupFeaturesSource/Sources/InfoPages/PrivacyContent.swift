import SwiftUI
import DesignSystem

// MARK: - Privacy page content model
//
// All copy for the Privacy page lives here as placeholder text so it can be
// rewritten in one place. Every string / group below is marked `// TODO` —
// replace these with the final Qontrol privacy copy and asset names.

/// A privacy "feature tile" (Tracking, Browsing, Assistant, …). Rendered as a
/// tall, full-bleed portrait tile whose image (or gradient fallback) fills it.
struct PrivacyPillar: Identifiable {
    let id: String
    /// Short title, ideally 2–4 words. Line breaks in the string are honored so
    /// it can stack vertically Apple-style (e.g. "Decide who\ncan track you").
    let title: String
    /// Longer copy revealed when the tile is expanded.
    let summary: String
    /// SF Symbol used in the gradient fallback and as a small glyph.
    let systemImage: String
    /// Gradient fallback colors, shown until a real asset is provided.
    let accent: [Color]
    /// TODO: set an asset catalog image name to replace the gradient fallback.
    var imageName: String? = nil
    var linkTitle: String? = nil
}

/// A compact "learn more" topic tile.
struct PrivacyTopic: Identifiable {
    let id: String
    let title: String
    let caption: String
    let systemImage: String
}

enum PrivacyContent {
    // TODO: replace hero eyebrow glyph + headline + statement copy.
    static let heroSymbol = "lock.fill"
    static let heroTitle = "Privacy. That's Cupertino."
    static let heroStatement =
        "Privacy is a fundamental right. It's also one of our core values — "
        + "which is why we design our products and services to protect it."
    static let heroActionTitle = "Watch the film"

    // TODO: replace "committed to your data" statement band copy.
    static let commitmentTitle = "We're committed to protecting your data."
    static let commitmentBody =
        "Our products and features include privacy technologies designed to minimize "
        + "how much of your data we — or anyone else — can access. Powerful security "
        + "features help prevent anyone except you from reaching your information."

    // TODO: replace the "apps mind their business" section eyebrow + headline.
    static let featuresTitle = "Our features mind their business. Not yours."

    // TODO: replace the feature tiles (titles, summaries, glyphs, images, links).
    static let pillars: [PrivacyPillar] = [
        PrivacyPillar(
            id: "tracking",
            title: "Decide who\ncan track you.",
            summary: "Apps must ask before they track your activity across other companies' apps and sites. You can change your mind for any app at any time.",
            systemImage: "hand.raised.fill",
            accent: [Color(hex: 0x5E5CE6), Color(hex: 0x8E8CF0)],
            imageName: nil, // TODO: add asset, e.g. "privacy_tracking"
            linkTitle: "See how it works"
        ),
        PrivacyPillar(
            id: "browsing",
            title: "Browse without\nbeing followed.",
            summary: "Intelligent tracking prevention uses on-device learning to help stop advertisers from following you across the web.",
            systemImage: "safari.fill",
            accent: [Color(hex: 0x0A84FF), Color(hex: 0x64D2FF)],
            imageName: nil, // TODO: add asset, e.g. "privacy_browsing"
            linkTitle: "See how it works"
        ),
        PrivacyPillar(
            id: "messages",
            title: "Messages stay\nbetween you.",
            summary: "Content is encrypted between devices, so it stays between you and whoever you choose to share it with — and no one else.",
            systemImage: "envelope.fill",
            accent: [Color(hex: 0x30D158), Color(hex: 0x66E39A)],
            imageName: nil, // TODO: add asset, e.g. "privacy_messages"
            linkTitle: "See how it works"
        ),
        PrivacyPillar(
            id: "location",
            title: "Your route,\nnot your profile.",
            summary: "You decide which apps can use your location, and share it only when it makes sense. Where you go isn't tied to your identity.",
            systemImage: "location.fill",
            accent: [Color(hex: 0xFF9F0A), Color(hex: 0xFFD60A)],
            imageName: nil, // TODO: add asset, e.g. "privacy_location"
            linkTitle: "See how it works"
        ),
        PrivacyPillar(
            id: "assistant",
            title: "Learns what you\nneed. Not who\nyou are.",
            summary: "As much learning as possible happens on your device, so your requests aren't associated with you.",
            systemImage: "waveform",
            accent: [Color(hex: 0xFF375F), Color(hex: 0xFF80AB)],
            imageName: nil, // TODO: add asset, e.g. "privacy_assistant"
            linkTitle: "See how it works"
        ),
        PrivacyPillar(
            id: "health",
            title: "Health records\nunder wraps.",
            summary: "Your health data is encrypted and only accessible with your passcode or biometrics. You control who gets to see it.",
            systemImage: "heart.fill",
            accent: [Color(hex: 0xFF2D55), Color(hex: 0xFF6482)],
            imageName: nil, // TODO: add asset, e.g. "privacy_health"
            linkTitle: "See how it works"
        ),
    ]

    // TODO: replace the "learn more" section title + topic tiles.
    static let learnMoreTitle = "Learn more about how we protect your data."
    static let topics: [PrivacyTopic] = [
        PrivacyTopic(
            id: "apps",
            title: "Apps",
            caption: "How your data is handled inside and across apps.",
            systemImage: "square.grid.2x2.fill"
        ),
        PrivacyTopic(
            id: "web",
            title: "Browsing the web",
            caption: "Protections that travel with you online.",
            systemImage: "globe"
        ),
        PrivacyTopic(
            id: "devices",
            title: "Your devices",
            caption: "On-device processing and secure storage.",
            systemImage: "laptopcomputer.and.iphone"
        ),
        PrivacyTopic(
            id: "account",
            title: "Your account",
            caption: "Manage what you share and how it's used.",
            systemImage: "person.crop.circle.fill"
        ),
    ]

    // TODO: replace the transparency footer note + control link labels.
    static let transparencyTitle = "Transparency & control"
    static let transparencyBody =
        "See how we respond to data requests, and manage the information associated "
        + "with your account whenever you like."
    static let transparencyPrimaryTitle = "Manage your privacy"
    static let transparencySecondaryTitle = "Read our Privacy Policy"
}
