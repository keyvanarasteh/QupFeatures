import DesignSystem
import FoundryAPI
import SwiftUI

struct KbListView: View {
    @EnvironmentObject private var state: KbState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors

    @State private var searchDebounce: Task<Void, Never>?
    @State private var confirmDeleteId: String?
    @State private var createOpen = false
    @State private var toast: Toast?

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
        .sheet(isPresented: $createOpen) { KbCreateView() }
        .alert("Delete KB entry?", isPresented: confirmDeleteBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteId = nil }
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId {
                    Task {
                        let ok = await state.remove(id)
                        toast = ok ? .success("Entry deleted") : .error(state.error ?? "Delete failed")
                        confirmDeleteId = nil
                    }
                }
            }
        } message: { Text("This cannot be undone.") }
    }

    private func loadInitial() async {
        await courses.loadList()
        await state.loadList()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Knowledge Base").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Manage course KB documents and sections.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
            CupertinoPrimaryButton("New Entry", systemImage: "plus", expands: false) { createOpen = true }
        }
    }

    private var filterRow: some View {
        HStack {
            TextField("Search label or ID…", text: $state.search)
                .textFieldStyle(.roundedBorder)
                .onChange(of: state.search) { _, _ in
                    searchDebounce?.cancel()
                    searchDebounce = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await state.loadList()
                    }
                }
            Picker("Course", selection: $state.courseFilter) {
                Text("All courses").tag("")
                ForEach(courses.courses, id: \.id) { c in
                    Text(c.nameEn).tag(c.id)
                }
            }
            .onChange(of: state.courseFilter) { _, _ in
                Task { await state.loadList() }
            }
            CupertinoPrimaryButton("Search", systemImage: "magnifyingglass", expands: false) {
                Task { await state.loadList() }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if state.loading.list && state.entries.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else if state.entries.isEmpty {
            EmptyStateView(title: "No entries", message: "No KB entries found.", systemImage: "doc.text")
        } else {
            listTable
            pagination
        }
    }

    private var listTable: some View {
        VStack(spacing: 0) {
            ForEach(state.entries) { entry in
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(value: entry.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.primary)
                            HStack {
                                Text(entry.id).font(Theme.Typography.caption2.monospaced()).foregroundStyle(colors.mutedFg)
                                Text(entry.courseNameEn ?? entry.courseId).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) { confirmDeleteId = entry.id } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(colors.danger)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                if entry.id != state.entries.last?.id { SoftDivider() }
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
