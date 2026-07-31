import SwiftUI
import DesignSystem
import WikiAPI

/// An article card for lists, search results, and admin views.
public struct WikiArticleCardView: View {
    @Environment(\.cupertinoColors) private var colors
    let article: WikiArticleStub
    var showSection: Bool
    var compact: Bool
    var selected: Bool
    var onSelect: ((Int) -> Void)?
    var onTap: (() -> Void)?

    public init(
        article: WikiArticleStub,
        showSection: Bool = false,
        compact: Bool = false,
        selected: Bool = false,
        onSelect: ((Int) -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.article = article
        self.showSection = showSection
        self.compact = compact
        self.selected = selected
        self.onSelect = onSelect
        self.onTap = onTap
    }

    public var body: some View {
        Button { onTap?() } label: { content }
            .buttonStyle(.plain)
            .background(
                selected ? colors.primarySoft : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(selected ? colors.primary.opacity(0.3) : colors.border.opacity(0.5), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .accessibilityLabel("Article: \(article.title)")
    }

    @ViewBuilder
    private var content: some View {
        if compact {
            compactLayout
        } else {
            fullLayout
        }
    }

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                if let onSelect {
                    Toggle(isOn: Binding(
                        get: { selected },
                        set: { onSelect($0 ? article.id : article.id) }
                    )) { EmptyView() }
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }

                Text(article.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)

                Spacer()

                WikiVisibilityBadge(article.visibility)
                WikiStatusBadge(article.status)
            }

            if showSection, let slug = article.sectionSlug {
                Text(slug)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if let desc = article.description {
                Text(desc)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let keywords = article.keywords, !keywords.isEmpty {
                HStack(spacing: 4) {
                    ForEach(keywords.prefix(5), id: \.self) { tag in
                        WikiTagChip(tag)
                    }
                    if keywords.count > 5 {
                        Text("+\(keywords.count - 5)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                Label("\(article.viewCount)", systemImage: "eye")
                Text("v\(article.version)")
                Text(article.updatedAt)
                    .lineLimit(1)
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.md)
    }

    private var compactLayout: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(article.title)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(colors.fg)
                .lineLimit(1)

            Spacer()

            WikiStatusBadge(article.status)
            WikiVisibilityBadge(article.visibility)

            Text(article.updatedAt)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}
