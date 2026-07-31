import DesignSystem
import FoundryAPI
import SwiftUI

struct ModulesListView: View {
    @EnvironmentObject private var state: ModulesState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors

    @State private var searchDebounce: Task<Void, Never>?
    @State private var confirmDeleteId: String?
    @State private var createOpen = false
    @State private var toast: Toast?

    private let diffColors: [String: Color] = [
        "beginner": .green, "intermediate": .orange, "advanced": .red
    ]

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if let toast { toastView(toast) }
                if let error = state.error { errorView(error) }
                filterRow
                listContent
            }
        }
        .task { await loadInitial() }
        .sheet(isPresented: $createOpen) { ModuleCreateView() }
        .alert("Delete module?", isPresented: confirmDeleteBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteId = nil }
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId {
                    Task {
                        let ok = await state.remove(id)
                        toast = ok ? .success("Module deleted") : .error(state.error ?? "Delete failed")
                        confirmDeleteId = nil
                    }
                }
            }
        } message: { Text("This cannot be undone.") }
    }

    private func loadInitial() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await courses.loadList() }
            group.addTask { await state.loadMeta() }
            group.addTask { await state.loadList() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Modules").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Manage course learning modules.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
            CupertinoPrimaryButton("New Module", systemImage: "plus", expands: false) { createOpen = true }
        }
    }

    private var filterRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                TextField("Search title or ID…", text: $state.search)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: state.search) { _, _ in
                        searchDebounce?.cancel()
                        searchDebounce = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            await state.loadList()
                        }
                    }
                CupertinoPrimaryButton("Search", systemImage: "magnifyingglass", expands: false) {
                    Task { await state.loadList() }
                }
            }
            HStack {
                Picker("Course", selection: $state.courseFilter) {
                    Text("All courses").tag("")
                    ForEach(courses.courses, id: \.id) { c in
                        Text(c.nameEn).tag(c.id)
                    }
                }
                .onChange(of: state.courseFilter) { _, _ in Task { await state.loadList() } }

                Picker("Category", selection: $state.categoryFilter) {
                    Text("All categories").tag("")
                    ForEach(state.meta?.categories ?? [], id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .onChange(of: state.categoryFilter) { _, _ in Task { await state.loadList() } }

                Picker("Difficulty", selection: $state.difficultyFilter) {
                    Text("All difficulties").tag("")
                    ForEach(state.meta?.difficulties ?? [], id: \.self) { d in
                        Text(d).tag(d)
                    }
                }
                .onChange(of: state.difficultyFilter) { _, _ in Task { await state.loadList() } }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if state.loading.list && state.modules.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else if state.modules.isEmpty {
            EmptyStateView(title: "No modules", message: "No modules found.", systemImage: "square.stack.3d.up")
        } else {
            listTable
            pagination
        }
    }

    private var listTable: some View {
        VStack(spacing: 0) {
            ForEach(state.modules) { mod in
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(value: mod.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(mod.title).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.primary)
                                if let diff = mod.difficulty {
                                    Text(diff.capitalized)
                                        .font(Theme.Typography.caption2.weight(.medium))
                                        .foregroundStyle(diffColors[diff.lowercased(), default: colors.fg])
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(diffColors[diff.lowercased(), default: colors.fg].opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            HStack {
                                Text(mod.id).font(Theme.Typography.caption2.monospaced()).foregroundStyle(colors.mutedFg)
                                Text(mod.courseNameEn ?? mod.courseId).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                                if let cat = mod.category { Text(cat).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg) }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) { confirmDeleteId = mod.id } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(colors.danger)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                if mod.id != state.modules.last?.id { SoftDivider() }
            }
        }
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private var pagination: some View {
        HStack {
            Text("\(state.total) total").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            Spacer()
            if state.lastPage > 1 {
                Button { Task { state.page -= 1; await state.loadList() } }
                    label: { Image(systemName: "chevron.left") }
                    .disabled(state.page <= 1 || state.loading.list)
                Text("Page \(state.page) of \(state.lastPage)").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                Button { Task { state.page += 1; await state.loadList() } }
                    label: { Image(systemName: "chevron.right") }
                    .disabled(state.page >= state.lastPage || state.loading.list)
            }
        }
        .buttonStyle(.bordered)
    }

    private var confirmDeleteBinding: Binding<Bool> {
        Binding(get: { confirmDeleteId != nil }, set: { if !$0 { confirmDeleteId = nil } })
    }
}
