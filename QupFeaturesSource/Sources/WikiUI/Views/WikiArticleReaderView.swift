import SwiftUI
import DesignSystem
import WikiAPI

/// Full article reader with Markdown/XML tab toggle.
public struct WikiArticleReaderView: View {
    @Environment(\.cupertinoColors) private var colors
    let article: WikiArticle

    @State private var selectedTab: ArticleTab = .markdown

    public enum ArticleTab: String, CaseIterable {
        case markdown = "Markdown"
        case xml = "XML"
        case rendered = "Preview"
    }

    public init(article: WikiArticle) {
        self.article = article
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack {
                Picker("Format", selection: $selectedTab) {
                    Text("Markdown").tag(ArticleTab.markdown)
                    if article.contentXml != nil {
                        Text("XML").tag(ArticleTab.xml)
                    }
                    Text("Preview").tag(ArticleTab.rendered)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                // Copy button
                Button {
                    copyContent()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.secondary)
                .help("Copy content")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()

            // Content
            ScrollView {
                switch selectedTab {
                case .markdown:
                    markdownContent
                case .xml:
                    xmlContent
                case .rendered:
                    renderedContent
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Article reader: \(article.title)")
    }

    @ViewBuilder
    private var markdownContent: some View {
        if let md = article.contentMd, !md.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(article.title)
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(colors.fg)

                if let desc = article.description {
                    Text(desc)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                MarkdownRenderView(markdown: md, id: "article-\(article.id)")
            }
            .padding(Theme.Spacing.xl)
        } else {
            EmptyStateView(title: "No Markdown Content", message: "This article has no markdown content.", systemImage: "doc.text")
                .padding()
        }
    }

    @ViewBuilder
    private var xmlContent: some View {
        if let xml = article.contentXml, !xml.isEmpty {
            ScrollView(.horizontal, showsIndicators: true) {
                Text(xml)
                    .font(Theme.Typography.code)
                    .foregroundStyle(colors.codeText)
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(colors.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(colors.codeBorder, lineWidth: 1)
            )
            .padding(Theme.Spacing.lg)
        } else {
            EmptyStateView(title: "No XML Content", message: "This article has no XML content.", systemImage: "chevron.left.forwardslash.chevron.right")
                .padding()
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        if let md = article.contentMd, !md.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(article.title)
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(colors.fg)

                if let desc = article.description {
                    Text(desc)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Rendered markdown via AttributedString
                MarkdownRenderView(markdown: md, id: "rendered-\(article.id)")
            }
            .padding(Theme.Spacing.xl)
        } else {
            markdownContent
        }
    }

    private func copyContent() {
        let content: String
        switch selectedTab {
        case .markdown: content = article.contentMd ?? ""
        case .xml: content = article.contentXml ?? ""
        case .rendered: content = article.contentMd ?? ""
        }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #else
        UIPasteboard.general.string = content
        #endif
    }
}

// MARK: - Simple Markdown Renderer

/// Renders markdown text using SwiftUI's AttributedString support (iOS 15+ / macOS 12+).
public struct MarkdownRenderView: View {
    let markdown: String
    let id: String

    public init(markdown: String, id: String) {
        self.markdown = markdown
        self.id = id
    }

    public var body: some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Fallback: plain text with code font
            ScrollView(.horizontal, showsIndicators: false) {
                Text(markdown)
                    .font(Theme.Typography.code)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
