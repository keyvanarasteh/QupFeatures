import DesignSystem
import FoundryAPI
import SwiftUI

struct ModuleCreateView: View {
    @EnvironmentObject private var state: ModulesState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var id = ""
    @State private var courseId = ""
    @State private var title = ""
    @State private var category = ""
    @State private var difficulty = ""
    @State private var description = ""
    @State private var steps = ""
    @State private var example = ""
    @State private var tools = ""
    @State private var coverImage = ""
    @State private var saving = false

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if let error = state.error { errorView(error) }
                form
            }
        }
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await courses.loadList() }
                group.addTask { await state.loadMeta() }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("New module").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Add a learning module to a course.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
        }
    }

    private var form: some View {
        VStack(spacing: Theme.Spacing.md) {
            labelled("Module ID *") {
                TextField("e.g. dsq-2026-module-01", text: $id).textFieldStyle(.roundedBorder)
            }
            HStack {
                labelled("Course *") {
                    Picker("", selection: $courseId) {
                        Text("Select course…").tag("")
                        ForEach(courses.courses, id: \.id) { c in
                            Text(c.nameEn).tag(c.id)
                        }
                    }
                }
                labelled("Title *") { TextField("Introduction to AI", text: $title).textFieldStyle(.roundedBorder) }
            }
            HStack {
                labelled("Category") {
                    TextField("e.g. Fundamentals", text: $category).textFieldStyle(.roundedBorder)
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
                TextEditor(text: $steps).frame(minHeight: 100).font(.caption.monospaced()).border(colors.border).cornerRadius(4)
            }
            HStack {
                labelled("Example") { TextEditor(text: $example).frame(height: 60).border(colors.border).cornerRadius(4) }
                labelled("Tools") { TextEditor(text: $tools).frame(height: 60).border(colors.border).cornerRadius(4) }
            }
            labelled("Cover image URL") { TextField("https://…", text: $coverImage).textFieldStyle(.roundedBorder) }

            HStack {
                Spacer()
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { dismiss() }
                    .tint(colors.mutedFg)
                CupertinoPrimaryButton("Create module", systemImage: "checkmark", expands: false) { Task { await create() } }
                    .disabled(saving || id.isEmpty || courseId.isEmpty || title.isEmpty)
                if saving { ProgressView() }
            }
        }
        .padding(Theme.Spacing.md)
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private func create() async {
        saving = true; defer { saving = false }
        let body = FoundryModuleCreateBody(
            id: id.trimmingCharacters(in: .whitespaces),
            courseId: courseId,
            title: title.trimmingCharacters(in: .whitespaces),
            category: category.trimmedNil,
            difficulty: difficulty.trimmedNil,
            description: description.trimmedNil,
            coverImage: coverImage.trimmedNil,
            tools: tools.trimmedNil
        )
        let result = await state.create(body)
        if result != nil { dismiss() }
    }
}
