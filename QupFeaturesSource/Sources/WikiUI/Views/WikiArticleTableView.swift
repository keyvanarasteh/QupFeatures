import SwiftUI
import DesignSystem
import WikiAPI

/// Admin sortable article table with inline status/visibility and selection.
public struct WikiArticleTableView: View {
    @Environment(\.cupertinoColors) private var colors

    let articles: [WikiArticleStub]
    let total: Int
    let loading: Bool
    @Binding var selectedIds: Set<Int>
    var onSelect: ((Int, Bool) -> Void)?
    var onSelectAll: ((Bool) -> Void)?
    var onSort: ((String) -> Void)?
    var sortCol: String
    var sortDir: String
    var onRowTap: ((WikiArticleStub) -> Void)?

    @State private var selectAll = false

    private let columns = [
        ColumnDef(id: "title", label: "Title", sortable: true, width: nil),
        ColumnDef(id: "section", label: "Section", sortable: true, width: 120),
        ColumnDef(id: "status", label: "Status", sortable: true, width: 100),
        ColumnDef(id: "visibility", label: "Visibility", sortable: true, width: 100),
        ColumnDef(id: "view_count", label: "Views", sortable: true, width: 70),
        ColumnDef(id: "version", label: "v", sortable: true, width: 40),
        ColumnDef(id: "updated_at", label: "Updated", sortable: true, width: 140),
    ]

    public init(
        articles: [WikiArticleStub],
        total: Int,
        loading: Bool = false,
        selectedIds: Binding<Set<Int>> = .constant([]),
        onSelect: ((Int, Bool) -> Void)? = nil,
        onSelectAll: ((Bool) -> Void)? = nil,
        onSort: ((String) -> Void)? = nil,
        sortCol: String = "updated_at",
        sortDir: String = "desc",
        onRowTap: ((WikiArticleStub) -> Void)? = nil
    ) {
        self.articles = articles
        self.total = total
        self.loading = loading
        _selectedIds = selectedIds
        self.onSelect = onSelect
        self.onSelectAll = onSelectAll
        self.onSort = onSort
        self.sortCol = sortCol
        self.sortDir = sortDir
        self.onRowTap = onRowTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                // Checkbox column
                selectionToggle(
                    isOn: Binding(
                        get: { selectedIds.count == articles.count && !articles.isEmpty },
                        set: { onSelectAll?($0) }
                    )
                )
                .frame(width: 40)
                .padding(.leading, Theme.Spacing.sm)

                ForEach(columns) { col in
                    if let width = col.width {
                        sortableHeader(col)
                            .frame(width: width, alignment: .leading)
                    } else {
                        sortableHeader(col)
                    }
                }

                Spacer()
            }
            .padding(.vertical, Theme.Spacing.sm)
            .background(colors.surface)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(colors.border),
                alignment: .bottom
            )

            // Rows
            if loading, articles.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if articles.isEmpty {
                Spacer()
                EmptyStateView(title: "No Articles", message: "No articles match your filters.", systemImage: "doc.text")
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(articles) { article in
                        row(article)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(colors.border),
            alignment: .top
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Articles table, \(articles.count) of \(total)")
    }

    @ViewBuilder
    private func row(_ article: WikiArticleStub) -> some View {
        Button {
            onRowTap?(article)
        } label: {
            HStack(spacing: 0) {
                selectionToggle(
                    isOn: Binding(
                        get: { selectedIds.contains(article.id) },
                        set: { selected in
                            if selected { selectedIds.insert(article.id) }
                            else { selectedIds.remove(article.id) }
                            onSelect?(article.id, selected)
                        }
                    )
                )
                .frame(width: 40)
                .padding(.leading, Theme.Spacing.sm)

                Text(article.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(article.sectionSlug ?? "")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)

                WikiStatusBadge(article.status)
                    .frame(width: 100, alignment: .leading)

                WikiVisibilityBadge(article.visibility)
                    .frame(width: 100, alignment: .leading)

                Text("\(article.viewCount)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)

                Text("v\(article.version)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)

                Text(article.updatedAt)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                selectedIds.contains(article.id) ? colors.primarySoft : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sortableHeader(_ col: ColumnDef) -> some View {
        if col.sortable {
            Button {
                onSort?(col.id)
            } label: {
                HStack(spacing: 2) {
                    Text(col.label)
                        .font(Theme.Typography.captionEmphasized)
                        .foregroundStyle(sortCol == col.id ? colors.primary : .secondary)
                    if sortCol == col.id {
                        Image(systemName: sortDir == "asc" ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                            .foregroundStyle(colors.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(col.label)
                .font(Theme.Typography.captionEmphasized)
                .foregroundStyle(.secondary)
        }
    }

    /// macOS checkbox Toggle; square glyph button on iOS (`.checkbox` is macOS-only).
    @ViewBuilder
    private func selectionToggle(isOn: Binding<Bool>) -> some View {
        #if os(macOS)
        Toggle(isOn: isOn) { EmptyView() }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .labelsHidden()
        #else
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                .font(.body)
                .foregroundStyle(isOn.wrappedValue ? colors.primary : .secondary)
        }
        .buttonStyle(.plain)
        #endif
    }
}

private struct ColumnDef: Identifiable {
    let id: String
    let label: String
    let sortable: Bool
    let width: CGFloat?
}
