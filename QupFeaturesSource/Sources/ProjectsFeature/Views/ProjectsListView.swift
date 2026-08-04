import DesignSystem
import FeatureContracts
import ProjectsAPI
import SwiftUI

/// Ported from `routes/projects/+page.svelte`: header, search + filter panel,
/// project list, create-project sheet, admin stats, and the GitHub account
/// sync plan/writeback workflow.
public struct ProjectsListView: View {
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors

    let context: FeatureContext
    let onSelect: (Project) -> Void

    @State private var filtersOpen = false
    @State private var createOpen = false
    @State private var adminOpen = false
    @State private var syncOpen = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    public init(context: FeatureContext, onSelect: @escaping (Project) -> Void) {
        self.context = context
        self.onSelect = onSelect
    }

    private var activeFilterCount: Int {
        [
            state.filter.statusID != nil,
            state.filter.typeID != nil,
            !state.filter.tag.isEmpty,
            !state.filter.lang.isEmpty,
            !state.filter.framework.isEmpty,
            state.filter.isPrivate != nil,
            state.filter.isActive != nil,
        ].filter { $0 }.count
    }

    private var languageOptions: [String] {
        Array(Set(state.projects.compactMap(\.programmingLanguage))).sorted()
    }

    private var frameworkOptions: [String] {
        Array(Set(state.projects.compactMap(\.framework))).sorted()
    }

    /// `state.allTags` is the authoritative catalog from `GET /projects/tags`;
    /// this falls back to tags visible in the currently-loaded page only if
    /// that hasn't loaded yet (e.g. `loadMeta()` hasn't returned).
    private var tagOptions: [String] {
        state.allTags.isEmpty
            ? Array(Set(state.projects.flatMap { $0.tags ?? [] })).sorted()
            : state.allTags
    }

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                searchAndFilterRow
                if filtersOpen { filterPanel }
                if let error = state.error {
                    Text(error).foregroundStyle(colors.danger)
                }

                if state.loading.list {
                    ProgressView().frame(maxWidth: .infinity)
                } else if state.projects.isEmpty {
                    EmptyStateView(
                        title: "No projects",
                        message: searchText.isEmpty && activeFilterCount == 0
                            ? "No projects yet."
                            : "No projects match your filters.",
                        systemImage: "folder"
                    )
                } else {
                    listView
                }
            }
        }
        .navigationTitle("Projects")
        .task {
            await state.loadMeta()
            await state.loadProjects()
        }
        .sheet(isPresented: $createOpen) {
            CreateProjectSheet { project in onSelect(project) }
        }
        .sheet(isPresented: $adminOpen) {
            ProjectsAdminSheet()
        }
        .sheet(isPresented: $syncOpen) {
            ProjectsSyncSheet(client: context.qlineClient)
        }
    }

    /// Title and actions on one line where they fit, otherwise the actions drop
    /// to their own line. A plain `HStack` compresses the labels instead, which
    /// on a phone hyphenates "Admin" mid-word.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                headerTitle
                Spacer(minLength: Theme.Spacing.md)
                headerActions
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headerTitle
                HStack(spacing: Theme.Spacing.sm) {
                    headerActions
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var headerTitle: some View {
        Text("Projects").font(Theme.Typography.title).foregroundStyle(colors.fg)
    }

    /// `fixedSize` keeps each label at its natural width so `ViewThatFits` sees
    /// a truthful ideal size rather than one the labels have already shrunk to.
    @ViewBuilder
    private var headerActions: some View {
        Button {
            adminOpen = true
        } label: {
            Label("Admin", systemImage: "chart.bar").fixedSize()
        }
        .buttonStyle(.bordered)
        Button {
            syncOpen = true
        } label: {
            Label("Sync", systemImage: "arrow.triangle.2.circlepath").fixedSize()
        }
        .buttonStyle(.bordered)
        Button {
            createOpen = true
        } label: {
            Label("New Project", systemImage: "plus").fixedSize()
        }
        .buttonStyle(.borderedProminent)
        .tint(colors.primary)
    }

    private var searchAndFilterRow: some View {
        HStack {
            TextField("Search by name, description, slug…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await state.setFilter { $0.q = newValue }
                    }
                }
            Button {
                filtersOpen.toggle()
            } label: {
                Label("Filters\(activeFilterCount > 0 ? " (\(activeFilterCount))" : "")", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        }
    }

    private var filterPanel: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Picker("Status", selection: Binding(
                    get: { state.filter.statusID },
                    set: { newValue in Task { await state.setFilter { $0.statusID = newValue } } }
                )) {
                    Text("All statuses").tag(Int?.none)
                    ForEach(state.statuses) { status in
                        Text(status.displayName).tag(Int?.some(status.id))
                    }
                }

                Picker("Type", selection: Binding(
                    get: { state.filter.typeID },
                    set: { newValue in Task { await state.setFilter { $0.typeID = newValue } } }
                )) {
                    Text("All types").tag(Int?.none)
                    ForEach(state.types) { type in
                        Text(type.displayName).tag(Int?.some(type.id))
                    }
                }

                if !languageOptions.isEmpty {
                    Picker("Language", selection: Binding(
                        get: { state.filter.lang },
                        set: { newValue in Task { await state.setFilter { $0.lang = newValue } } }
                    )) {
                        Text("All languages").tag("")
                        ForEach(languageOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                if !frameworkOptions.isEmpty {
                    Picker("Framework", selection: Binding(
                        get: { state.filter.framework },
                        set: { newValue in Task { await state.setFilter { $0.framework = newValue } } }
                    )) {
                        Text("All frameworks").tag("")
                        ForEach(frameworkOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                if !tagOptions.isEmpty {
                    Picker("Tag", selection: Binding(
                        get: { state.filter.tag },
                        set: { newValue in Task { await state.setFilter { $0.tag = newValue } } }
                    )) {
                        Text("All tags").tag("")
                        ForEach(tagOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                Picker("Visibility", selection: Binding(
                    get: { state.filter.isPrivate },
                    set: { newValue in Task { await state.setFilter { $0.isPrivate = newValue } } }
                )) {
                    Text("All").tag(Bool?.none)
                    Text("Private").tag(Bool?.some(true))
                    Text("Public").tag(Bool?.some(false))
                }

                Picker("Active state", selection: Binding(
                    get: { state.filter.isActive },
                    set: { newValue in Task { await state.setFilter { $0.isActive = newValue } } }
                )) {
                    Text("All").tag(Bool?.none)
                    Text("Active").tag(Bool?.some(true))
                    Text("Inactive").tag(Bool?.some(false))
                }

                if activeFilterCount > 0 {
                    Button("Clear filters") {
                        searchText = ""
                        Task { await state.setFilter { $0 = ProjectFilter() } }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(colors.mutedFg)
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ForEach(state.projects) { project in
                Button {
                    onSelect(project)
                } label: {
                    ProjectRowView(project: project)
                }
                .buttonStyle(.plain)
                if project.id != state.projects.last?.id {
                    SoftDivider()
                }
            }
        }
    }
}

/// One row in the project list — name-initial badge, privacy icon, status
/// badge, description/tags, member count. Direct port of the source's
/// per-row markup (`routes/projects/+page.svelte`'s `{#each projects}`).
public struct ProjectRowView: View {
    @Environment(\.cupertinoColors) private var colors
    let project: Project

    public init(project: Project) { self.project = project }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill((project.typeColor.flatMap(Color.init(hexString:)) ?? colors.primary).opacity(0.12))
                Text(project.name.prefix(1).uppercased())
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(project.typeColor.flatMap(Color.init(hexString:)) ?? colors.primary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(project.name).font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                    Spacer()
                    if !project.isActive {
                        StatusBadge("Inactive", tone: .neutral)
                    }
                    Image(systemName: project.isPrivate ? "lock.fill" : "globe")
                        .font(.caption2)
                        .foregroundStyle(colors.mutedFg)
                    if let statusDisplay = project.statusDisplay {
                        StatusBadge(statusDisplay, tone: .info)
                    }
                }

                if let description = project.description, !description.isEmpty {
                    Text(description).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg).lineLimit(1)
                } else if let secondary = [project.framework, project.programmingLanguage].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty ?? project.typeDisplay {
                    Text(secondary).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg).lineLimit(1)
                }

                if let tags = project.tags, !tags.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(tags.prefix(4), id: \.self) { tag in
                            CupertinoChip(tag)
                        }
                        if tags.count > 4 {
                            Text("+\(tags.count - 4)").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                        }
                    }
                }

                if let memberCount = project.memberCount, memberCount > 0 {
                    Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(colors.mutedFg)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Color {
    /// Parses a `"#rrggbb"`/`"rrggbb"` string from the backend's `type_color`/
    /// `status_color` fields. `DesignSystem.Color(hex:)` only takes a `UInt64`
    /// literal, not a wire string, so this stays feature-local.
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
