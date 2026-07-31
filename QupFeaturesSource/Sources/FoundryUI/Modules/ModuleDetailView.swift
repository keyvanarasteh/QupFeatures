import DesignSystem
import FoundryAPI
import SwiftUI

struct ModuleDetailView: View {
    @EnvironmentObject private var state: ModulesState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let moduleId: String

    @State private var courseId = ""
    @State private var title = ""
    @State private var category = ""
    @State private var difficulty = ""
    @State private var description = ""
    @State private var steps = ""
    @State private var example = ""
    @State private var tools = ""
    @State private var coverImage = ""
    @State private var confirmDelete = false
    @State private var toast: Toast?
    @State private var saving = false

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if let toast { toastView(toast) }
                if let error = state.error { errorView(error) }

                if state.loading.detail {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let mod = state.current {
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        formView
                        infoPanel(mod)
                    }
                } else {
                    EmptyStateView(title: "Not found", message: "Module not found.", systemImage: "questionmark")
                }
            }
        }
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await courses.loadList() }
                group.addTask { await state.loadMeta() }
                group.addTask { await state.loadOne(moduleId) }
            }
        }
        .onChange(of: state.current) { _, mod in
            guard let m = mod else { return }
            courseId = m.courseId; title = m.title
            category = m.category ?? ""; difficulty = m.difficulty ?? ""
            description = m.description ?? ""
            steps = m.steps.map { String(describing: $0) } ?? ""
            example = m.example ?? ""; tools = m.tools ?? ""; coverImage = m.coverImage ?? ""
        }
        .alert("Delete module?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await state.remove(moduleId)
                    if ok { dismiss() }
                    else { toast = .error(state.error ?? "Delete failed") }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(state.current?.title ?? moduleId).font(Theme.Typography.title).foregroundStyle(colors.fg)
                    if let diff = state.current?.difficulty {
                        Text(diff.capitalized).font(Theme.Typography.caption2.weight(.medium))
                            .foregroundStyle(diffColor(diff))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(diffColor(diff).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(moduleId).font(Theme.Typography.caption.monospaced()).foregroundStyle(colors.mutedFg)
            }
            Spacer()
            Button(role: .destructive) { confirmDelete = true } label: { Text("Delete").font(Theme.Typography.caption) }
                .buttonStyle(.bordered).tint(colors.danger)
        }
    }

    private var formView: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                labelled("Course *") {
                    Picker("", selection: $courseId) {
                        ForEach(courses.courses, id: \.id) { c in
                            Text(c.nameEn).tag(c.id)
                        }
                    }
                }
                labelled("Title *") { TextField("Required", text: $title).textFieldStyle(.roundedBorder) }
            }
            HStack {
                labelled("Category") {
                    TextField("", text: $category).textFieldStyle(.roundedBorder)
                }
                labelled("Difficulty") {
                    Picker("", selection: $difficulty) {
                        Text("None").tag("")
                        ForEach(state.meta?.difficulties ?? ["beginner", "intermediate", "advanced"], id: \.self) { d in
                            Text(d).tag(d)
                        }
                    }
                }
            }
            labelled("Description") {
                TextEditor(text: $description).frame(height: 60).border(colors.border).cornerRadius(4)
            }
            labelled("Steps (JSON)") {
                TextEditor(text: $steps).frame(minHeight: 120).font(.caption.monospaced()).border(colors.border).cornerRadius(4)
            }
            HStack {
                labelled("Example") { TextEditor(text: $example).frame(height: 60).border(colors.border).cornerRadius(4) }
                labelled("Tools") { TextEditor(text: $tools).frame(height: 60).border(colors.border).cornerRadius(4) }
            }
            labelled("Cover image URL") { TextField("https://…", text: $coverImage).textFieldStyle(.roundedBorder) }

            HStack {
                Spacer()
                if saving { ProgressView() }
                CupertinoPrimaryButton("Save changes", systemImage: "checkmark", expands: false) { Task { await save() } }
                    .disabled(saving)
            }
        }
        .padding(Theme.Spacing.md)
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private func infoPanel(_ mod: FoundryModule) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("INFO").font(Theme.Typography.caption2.weight(.semibold)).foregroundStyle(colors.mutedFg)
                infoRow("ID", mod.id, mono: true)
                infoRow("Course", mod.courseNameEn ?? mod.courseId)
                infoRow("Category", mod.category ?? "—")
                infoRow("Difficulty", mod.difficulty ?? "—")
                infoRow("Created", mod.createdAt)
                infoRow("Updated", mod.updatedAt)
            }
            .padding(Theme.Spacing.sm)
            .background(colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
        }
        .frame(width: 240)
    }

    private func diffColor(_ d: String) -> Color {
        switch d.lowercased() { case "beginner": .green; case "intermediate": .orange; case "advanced": .red; default: colors.fg }
    }

    private func save() async {
        saving = true; defer { saving = false }
        let body = FoundryModuleUpdateBody(
            courseId: courseId, title: title.trimmingCharacters(in: .whitespaces),
            category: category.trimmedNil, difficulty: difficulty.trimmedNil,
            description: description.trimmedNil,
            coverImage: coverImage.trimmedNil, tools: tools.trimmedNil
        )
        let result = await state.update(moduleId, body)
        toast = result != nil ? .success("Module saved") : .error(state.error ?? "Save failed")
    }
}
