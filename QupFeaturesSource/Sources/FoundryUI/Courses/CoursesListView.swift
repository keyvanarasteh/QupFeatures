import DesignSystem
import FoundryAPI
import SwiftUI

struct CoursesListView: View {
    @EnvironmentObject private var state: CoursesState
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
                searchRow
                listContent
            }
        }
        .task { await state.loadList() }
        .sheet(isPresented: $createOpen) { CourseCreateView() }
        .alert("Delete course?", isPresented: confirmDeleteBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteId = nil }
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId {
                    Task {
                        let ok = await state.remove(id)
                        toast = ok ? .success("Course deleted") : .error(state.error ?? "Delete failed")
                        confirmDeleteId = nil
                    }
                }
            }
        } message: { Text("This will also remove all linked modules, KB entries, proposals and rosters. This cannot be undone.") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Courses").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Manage Foundry course definitions.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
            CupertinoPrimaryButton("New Course", systemImage: "plus", expands: false) { createOpen = true }
        }
    }

    private var searchRow: some View {
        HStack {
            TextField("Search by name, ID, year or code…", text: $state.search)
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
    }

    @ViewBuilder
    private var listContent: some View {
        if state.loading.list && state.courses.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else if state.courses.isEmpty {
            EmptyStateView(title: "No courses", message: "No courses found.", systemImage: "book")
        } else {
            listTable
            pagination
        }
    }

    private var listTable: some View {
        VStack(spacing: 0) {
            ForEach(state.courses) { course in
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(value: course.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.nameEn).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.primary)
                            HStack {
                                Text(course.id).font(Theme.Typography.caption2.monospaced()).foregroundStyle(colors.mutedFg)
                                if let year = course.year { Text(year).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg) }
                                if let semester = course.semester { Text("S\(semester)").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg) }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) { confirmDeleteId = course.id } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(colors.danger)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                if course.id != state.courses.last?.id { SoftDivider() }
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
