import SwiftUI
import DesignSystem
import WikiAPI

/// Meta panel for article reader — links, keywords, view info.
public struct WikiMetaSidebarView: View {
    @Environment(\.cupertinoColors) private var colors
    let article: WikiArticle
    var onTagClick: ((String) -> Void)?

    public init(article: WikiArticle, onTagClick: ((String) -> Void)? = nil) {
        self.article = article
        self.onTagClick = onTagClick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Meta links
            if let meta = article.meta {
                metaSection(meta)
            }

            // Keywords
            if let keywords = article.keywords, !keywords.isEmpty {
                SectionHeader("Keywords", systemImage: "tag")
                    .font(Theme.Typography.captionEmphasized)

                FlowLayout(spacing: 4) {
                    ForEach(keywords, id: \.self) { tag in
                        WikiTagChip(tag) { onTagClick?(tag) }
                    }
                }
            }

            // Info
            SectionHeader("Info", systemImage: "info.circle")
                .font(Theme.Typography.captionEmphasized)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label("\(article.viewCount) views", systemImage: "eye")
                HStack(spacing: Theme.Spacing.xs) {
                    Text("v\(article.version)")
                    Text("·")
                    Text("updated \(article.updatedAt)")
                }
                if let email = article.authorEmail {
                    Label(email, systemImage: "person")
                        .lineLimit(1)
                }
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.md)
        .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .frame(maxWidth: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Article meta")
    }

    @ViewBuilder
    private func metaSection(_ meta: WikiArticleMeta) -> some View {
        SectionHeader("Meta", systemImage: "link")
            .font(Theme.Typography.captionEmphasized)

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let url = meta.pypiUrl {
                Link(destination: URL(string: url)!) {
                    Label("PyPI", systemImage: "square.and.arrow.up")
                }
                .font(Theme.Typography.caption)
            }
            if let url = meta.docsUrl {
                Link(destination: URL(string: url)!) {
                    Label("Docs", systemImage: "doc.text")
                }
                .font(Theme.Typography.caption)
            }
            if let url = meta.githubUrl {
                Link(destination: URL(string: url)!) {
                    Label("GitHub", systemImage: "curlybraces")
                }
                .font(Theme.Typography.caption)
            }
            if let version = meta.version {
                Label("Version: \(version)", systemImage: "tag")
                    .font(Theme.Typography.caption)
            }
            if let license = meta.license {
                Label("License: \(license)", systemImage: "doc.plaintext")
                    .font(Theme.Typography.caption)
            }
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Simple flow layout for tags

/// A horizontal wrapping layout (iOS 16+ native, older OS uses VStack fallback).
public struct FlowLayout: Layout {
    let spacing: CGFloat

    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxH + spacing
                maxH = 0
            }
            maxH = max(maxH, size.height)
            x += size.width + spacing
            height = y + maxH
        }
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += maxH + spacing
                maxH = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxH = max(maxH, size.height)
            x += size.width + spacing
        }
    }
}
