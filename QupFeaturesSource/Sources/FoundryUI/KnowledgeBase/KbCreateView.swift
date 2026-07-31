import DesignSystem
import FoundryAPI
import SwiftUI

struct KbCreateView: View {
    @EnvironmentObject private var state: KbState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var id = ""
    @State private var courseId = ""
    @State private var label = ""
    @State private var docBasePath = ""
    @State private var sectionsJson = ""
    @State private var saving = false

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if let error = state.error { errorView(error) }
                form
            }
        }
        .task { await courses.loadList() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("New KB entry").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Add a knowledge base document to a course.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
        }
    }

    private var form: some View {
        VStack(spacing: Theme.Spacing.md) {
            labelled("Entry ID *") {
                TextField("e.g. dsq-2026-intro", text: $id).textFieldStyle(.roundedBorder)
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
                labelled("Label *") { TextField("Introduction", text: $label).textFieldStyle(.roundedBorder) }
            }
            labelled("Doc base path") { TextField("/docs/dsq-2026", text: $docBasePath).textFieldStyle(.roundedBorder) }
            labelled("Sections JSON *") {
                TextEditor(text: $sectionsJson).frame(minHeight: 150).font(.caption.monospaced()).border(colors.border).cornerRadius(4)
                Text("JSON array of section objects.").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
            }

            HStack {
                Spacer()
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { dismiss() }
                    .tint(colors.mutedFg)
                CupertinoPrimaryButton("Create entry", systemImage: "checkmark", expands: false) { Task { await create() } }
                    .disabled(saving || id.isEmpty || courseId.isEmpty || label.isEmpty)
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
        let body = FoundryKbCreateBody(
            id: id.trimmingCharacters(in: .whitespaces),
            courseId: courseId,
            label: label.trimmingCharacters(in: .whitespaces),
            docBasePath: docBasePath.trimmedNil
        )
        let result = await state.create(body)
        if result != nil { dismiss() }
    }
}
