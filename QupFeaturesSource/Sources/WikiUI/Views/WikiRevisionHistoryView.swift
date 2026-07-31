import SwiftUI
import DesignSystem
import WikiAPI

/// Revision history list with snapshot viewer and restore capability.
public struct WikiRevisionHistoryView: View {
    @Environment(\.cupertinoColors) private var colors
    let articleId: Int
    let currentVersion: Int
    let viewModel: WikiViewModel
    var onRestore: ((WikiRevision) -> Void)?

    @State private var selectedRevision: WikiRevision?
    @State private var showSnapshot = false

    public init(
        articleId: Int,
        currentVersion: Int,
        viewModel: WikiViewModel,
        onRestore: ((WikiRevision) -> Void)? = nil
    ) {
        self.articleId = articleId
        self.currentVersion = currentVersion
        self.viewModel = viewModel
        self.onRestore = onRestore
    }

    public var body: some View {
        HSplitView {
            // Revision list
            revisionsList

            // Snapshot viewer
            if showSnapshot, let rev = selectedRevision {
                snapshotView(rev)
                    .frame(minWidth: 300)
            }
        }
        .task {
            await viewModel.loadRevisions(articleId: articleId)
        }
        .frame(minHeight: 300)
    }

    private var revisionsList: some View {
        List {
            ForEach(viewModel.revisions) { revision in
                revisionRow(revision)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            selectedRevision = await viewModel.loadRevision(articleId: articleId, version: revision.version)
                            showSnapshot = true
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.loading.revisions {
                ProgressView()
            } else if viewModel.revisions.isEmpty {
                EmptyStateView(title: "No Revisions", message: "No revision history available.", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    @ViewBuilder
    private func revisionRow(_ revision: WikiRevisionStub) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                HStack(spacing: 4) {
                    Text("v\(revision.version)")
                        .font(Theme.Typography.captionEmphasized)
                        .foregroundStyle(revision.version == currentVersion ? colors.primary : colors.fg)

                    if revision.version == currentVersion {
                        Text("(current)")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(colors.primary)
                    }
                }

                Spacer()

                Text(revision.createdAt)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if let note = revision.changeNote {
                Text(note)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let email = revision.editorEmail {
                Text(email)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    @ViewBuilder
    private func snapshotView(_ revision: WikiRevision) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Snapshot v\(revision.version)")
                    .font(Theme.Typography.headline)
                Spacer()
                if revision.version != currentVersion {
                    Button("Restore") {
                        onRestore?(revision)
                    }
                    .buttonStyle(.primary)
                    .controlSize(.small)
                }
                Button { showSnapshot = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let md = revision.contentMd {
                        MarkdownRenderView(markdown: md, id: "rev-\(revision.id)")
                    }
                    if let xml = revision.contentXml {
                        DisclosureGroup("XML") {
                            Text(xml)
                                .font(Theme.Typography.code)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(colors.card)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(colors.border),
            alignment: .leading
        )
    }
}
