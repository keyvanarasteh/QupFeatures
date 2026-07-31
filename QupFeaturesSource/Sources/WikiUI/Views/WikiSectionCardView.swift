import SwiftUI
import DesignSystem
import WikiAPI

/// A section tile for the wiki landing grid.
public struct WikiSectionCardView: View {
    @Environment(\.cupertinoColors) private var colors
    let section: WikiSection
    let onTap: (() -> Void)?

    public init(section: WikiSection, onTap: (() -> Void)? = nil) {
        self.section = section
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    IconView(icon: section.icon)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.primary)

                    Text(section.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(colors.fg)
                        .lineLimit(1)

                    Spacer()
                }

                HStack(spacing: Theme.Spacing.md) {
                    if let count = section.articleCount {
                        Label("\(count)", systemImage: "doc.text")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let count = section.childCount {
                        Label("\(count)", systemImage: "folder")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let desc = section.description {
                    Text(desc)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .accessibilityLabel("Section: \(section.title)")
    }
}

/// Renders an icon from a section's icon string (emoji or SF symbol name).
struct IconView: View {
    let icon: String?

    var body: some View {
        if let icon {
            if icon.count <= 2, icon.unicodeScalars.allSatisfy({ $0.properties.isEmoji }) {
                Text(icon)
            } else {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}
