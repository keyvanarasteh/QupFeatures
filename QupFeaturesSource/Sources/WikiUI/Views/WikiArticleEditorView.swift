import SwiftUI
import DesignSystem
import WikiAPI

/// Comprehensive article editor with tabbed interface: Content · Access · Revisions.
public struct WikiArticleEditorView: View {
    @Environment(\.cupertinoColors) private var colors

    let article: WikiArticle?
    let sections: [WikiSection]
    let viewModel: WikiViewModel
    let onSave: (Either<WikiArticleCreate, WikiArticleUpdate>, Bool) async -> Void
    let onCancel: (() -> Void)?

    @State private var activeTab: EditorTab = .content
    @State private var title = ""
    @State private var slug = ""
    @State private var description = ""
    @State private var contentMd = ""
    @State private var contentXml = ""
    @State private var changeNote = ""
    @State private var sectionId: Int = 0
    @State private var visibility: WikiVisibility = .public
    @State private var status: WikiStatus = .draft
    @State private var sortOrder = ""
    @State private var keywords: [String] = []
    @State private var keywordInput = ""
    @State private var meta: WikiArticleMeta?
    @State private var showPreview = false
    @State private var saving = false

    public enum EditorTab: String, CaseIterable {
        case content = "Content"
        case access = "Access"
        case revisions = "Revisions"
    }

    private var isEditing: Bool { article != nil }

    public init(
        article: WikiArticle? = nil,
        sections: [WikiSection] = [],
        viewModel: WikiViewModel,
        onSave: @escaping (Either<WikiArticleCreate, WikiArticleUpdate>, Bool) async -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.article = article
        self.sections = sections
        self.viewModel = viewModel
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $activeTab) {
                ForEach(EditorTab.allCases, id: \.rawValue) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()

            // Use HSplitView on macOS for sidebar, simple VStack on iOS
            #if os(macOS)
            HSplitView {
                mainEditorArea
                if activeTab == .content {
                    editorSidebar
                        .frame(width: 260)
                        .background(colors.surface)
                }
            }
            #else
            VStack(spacing: 0) {
                mainEditorArea
            }
            #endif

            Divider()

            // Action buttons
            HStack {
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.secondary)
                }
                Spacer()
                Button("Save Draft") { Task { await save(publish: false) } }
                    .buttonStyle(.secondary)
                    .disabled(saving || title.isEmpty)
                Button("Publish") { Task { await save(publish: true) } }
                    .buttonStyle(.primary)
                    .disabled(saving || title.isEmpty)
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear(perform: populateFields)
        .disabled(saving)
        .overlay {
            if saving { ProgressView().controlSize(.large) }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Main editor area (extracted for HSplitView/VStack compatibility)

    @ViewBuilder
    private var mainEditorArea: some View {
        ScrollView {
            Group {
                switch activeTab {
                case .content: contentTab
                case .access: accessTab
                case .revisions: revisionsTab
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Content Tab

    @ViewBuilder
    private var contentTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LabeledContent("Title") {
                TextField("Article title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Typography.title3)
                    .onChange(of: title) { _, new in
                        guard !isEditing else { return }
                        slug = slugify(new)
                    }
            }

            LabeledContent("Slug") {
                TextField("article-slug", text: $slug)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Typography.code)
                    .disableAutocorrection(true)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
            }

            LabeledContent("Description") {
                TextField("Brief description…", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            // Markdown editor
            HStack {
                Text("Markdown")
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(colors.fg)
                Spacer()
                Toggle("Preview", isOn: $showPreview)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(Theme.Typography.caption)
            }

            if showPreview {
                MarkdownRenderView(markdown: contentMd, id: "preview")
                    .padding(Theme.Spacing.md)
                    .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .stroke(colors.border, lineWidth: 1)
                    )
            } else {
                // Toolbar
                HStack(spacing: 2) {
                    mdToolbarButton("bold") { wrapSelection("**", "**") }
                    mdToolbarButton("italic") { wrapSelection("_", "_") }
                    mdToolbarButton("number") { wrapSelection("# ", "") }
                    mdToolbarButton("link") { wrapSelection("[", "](url)") }
                    mdToolbarButton("rectangle.and.pencil.and.ellipsis") { wrapSelection("```\n", "\n```") }
                    mdToolbarButton("tablecells") { insertAtCursor("\n| Header |\n|--------|\n| Cell   |\n") }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous))

                TextEditor(text: $contentMd)
                    .font(Theme.Typography.code)
                    .frame(minHeight: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                            .stroke(colors.border, lineWidth: 1)
                    )
            }

            // XML (collapsible)
            DisclosureGroup("XML Content") {
                TextEditor(text: $contentXml)
                    .font(Theme.Typography.code)
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                            .stroke(colors.border, lineWidth: 1)
                    )
            }

            // Change note (for updates)
            if isEditing {
                LabeledContent("Change Note") {
                    TextField("What changed?", text: $changeNote)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Editor sidebar

    private var editorSidebar: some View {
        Form {
            Section("Settings") {
                Picker("Section", selection: $sectionId) {
                    ForEach(sections) { sec in
                        Text(sec.title).tag(sec.id)
                    }
                }

                Picker("Visibility", selection: $visibility) {
                    ForEach(WikiVisibility.allDisplayCases, id: \.rawValue) { v in
                        Text(v.displayName).tag(v)
                    }
                }

                Picker("Status", selection: $status) {
                    ForEach(WikiStatus.allDisplayCases, id: \.rawValue) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                LabeledContent("Sort Order") {
                    TextField("0", text: $sortOrder)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }

            Section("Keywords") {
                HStack(spacing: 2) {
                    ForEach(keywords, id: \.self) { tag in
                        WikiTagChip(tag, removable: true) {
                            keywords.removeAll { $0 == tag }
                        }
                    }
                    TextField("Add…", text: $keywordInput)
                        .textFieldStyle(.plain)
                        .onSubmit(commitKeyword)
                }
            }

            WikiMetaEditorView(meta: $meta)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - Access Tab

    @ViewBuilder
    private var accessTab: some View {
        if let article {
            WikiAccessManagerView(
                articleId: article.id,
                isOwner: article.isOwner != 0,
                viewModel: viewModel
            )
        } else {
            Text("Save the article first to manage access.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    // MARK: - Revisions Tab

    @ViewBuilder
    private var revisionsTab: some View {
        if let article {
            WikiRevisionHistoryView(
                articleId: article.id,
                currentVersion: article.version,
                viewModel: viewModel
            )
        } else {
            Text("Save the article first to view revisions.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    // MARK: - Helpers

    private func populateFields() {
        guard let article else {
            sectionId = sections.first?.id ?? 0
            return
        }
        title = article.title
        slug = article.slug
        description = article.description ?? ""
        contentMd = article.contentMd ?? ""
        contentXml = article.contentXml ?? ""
        sectionId = article.sectionId
        visibility = article.visibility
        status = article.status
        sortOrder = String(article.sortOrder)
        keywords = article.keywords ?? []
        meta = article.meta
    }

    private func save(publish: Bool) async {
        saving = true
        if isEditing, let article {
            let payload = WikiArticleUpdate(
                title: title, slug: slug,
                description: description.isEmpty ? nil : description,
                contentMd: contentMd, contentXml: contentXml.isEmpty ? nil : contentXml,
                keywords: keywords.isEmpty ? nil : keywords,
                meta: meta,
                visibility: visibility,
                status: publish ? .published : status,
                sortOrder: Int(sortOrder),
                changeNote: changeNote.isEmpty ? nil : changeNote
            )
            await onSave(.right(payload), publish)
        } else {
            let payload = WikiArticleCreate(
                sectionId: sectionId, slug: slug, title: title,
                description: description.isEmpty ? nil : description,
                contentMd: contentMd, contentXml: contentXml.isEmpty ? nil : contentXml,
                keywords: keywords.isEmpty ? nil : keywords,
                meta: meta,
                visibility: visibility,
                status: publish ? .published : status,
                sortOrder: Int(sortOrder)
            )
            await onSave(.left(payload), publish)
        }
        saving = false
    }

    private func mdToolbarButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .help("Format")
    }

    private func wrapSelection(_ pre: String, _ post: String) {
        contentMd += "\(pre)text\(post)"
    }

    private func insertAtCursor(_ text: String) {
        contentMd += text
    }

    private func commitKeyword() {
        let trimmed = keywordInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !keywords.contains(trimmed) else { return }
        keywords.append(trimmed)
        keywordInput = ""
    }

    private func slugify(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

/// Either type for create vs update payloads.
public enum Either<L, R> {
    case left(L)
    case right(R)
}
