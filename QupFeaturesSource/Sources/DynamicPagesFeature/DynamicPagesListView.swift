import DesignSystem
import DynamicPagesAPI
import SwiftUI

/// Sidebar / list of dynamic pages with search and filters.
public struct DynamicPagesListView: View {
    @EnvironmentObject private var state: DynamicPagesState
    @Environment(\.cupertinoColors) private var colors

    @Binding var selectedPageId: Int?
    var onCreate: () -> Void

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var scopeFilter = ""
    @State private var showInactive = false

    public init(selectedPageId: Binding<Int?>, onCreate: @escaping () -> Void) {
        self._selectedPageId = selectedPageId
        self.onCreate = onCreate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            filterRow
            if let error = state.error {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.danger)
                    .padding(.horizontal, Theme.Spacing.sm)
            }
            listContent
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dynamic Pages")
                    .font(Theme.Typography.headline)
                Text("First-class SDUI documents")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer()
            Button(action: onCreate) {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var filterRow: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(colors.mutedFg)
                TextField("Search key or title", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            var filter = state.filter
                            filter.q = newValue
                            await state.loadPages(filter)
                        }
                    }
            }
            .padding(Theme.Spacing.sm)
            .background(colors.muted, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))

            HStack {
                Picker("Scope", selection: $scopeFilter) {
                    Text("All").tag("")
                    Text("Global").tag("global")
                    Text("User").tag("user")
                }
                .onChange(of: scopeFilter) { _, newValue in
                    var filter = state.filter
                    filter.scopeType = newValue.isEmpty ? nil : newValue
                    Task { await state.loadPages(filter) }
                }

                Toggle("Inactive", isOn: $showInactive)
                    .toggleStyle(.switch)
                    .onChange(of: showInactive) { _, newValue in
                        var filter = state.filter
                        filter.includeInactive = newValue
                        Task { await state.loadPages(filter) }
                    }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    @ViewBuilder
    private var listContent: some View {
        if state.loading.list && state.pages.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.pages.isEmpty {
            EmptyStateView(
                title: "No pages",
                message: searchText.isEmpty
                    ? "Create a DynamicDocument stored in dynamic_pages."
                    : "No pages match your filters.",
                systemImage: "doc.richtext",
                actionTitle: "New Page",
                action: onCreate
            )
            .padding()
        } else {
            List(state.pages, selection: $selectedPageId) { page in
                pageRow(page)
                    .tag(page.id)
                    .opacity(page.isActive ? 1 : 0.55)
            }
            #if os(macOS)
            .listStyle(.sidebar)
            #endif
        }
    }

    private func pageRow(_ page: DynamicPage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(page.title)
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if page.isSystem {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(colors.mutedFg)
                }
            }
            Text(page.pageKey)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(colors.mutedFg)
                .lineLimit(1)
            HStack(spacing: Theme.Spacing.xs) {
                badge(page.scopeType)
                badge(page.visibility)
                if !page.isActive {
                    badge("inactive")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colors.muted, in: Capsule())
            .foregroundStyle(colors.mutedFg)
    }
}
