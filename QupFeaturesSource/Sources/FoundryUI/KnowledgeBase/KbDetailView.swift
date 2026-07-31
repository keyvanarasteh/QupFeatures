import DesignSystem
import FoundryAPI
import SwiftUI

struct KbDetailView: View {
    @EnvironmentObject private var state: KbState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let entryId: String

    @State private var courseId = ""
    @State private var label = ""
    @State private var docBasePath = ""
    @State private var sectionsJson = ""
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
                } else if let entry = state.current {
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        formView
                        infoPanel(entry)
                    }
                } else {
                    EmptyStateView(title: "Not found", message: "Entry not found.", systemImage: "questionmark")
                }
            }
        }
        .task {
            await courses.loadList()
            await state.loadOne(entryId)
        }
        .onChange(of: state.current) { _, entry in
            guard let e = entry else { return }
            courseId = e.courseId; label = e.label
            docBasePath = e.docBasePath ?? ""
            sectionsJson = e.sectionsJson.map { String(describing: $0) } ?? ""
        }
        .alert("Delete KB entry?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await state.remove(entryId)
                    if ok { dismiss() }
                    else { toast = .error(state.error ?? "Delete failed") }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(state.current?.label ?? entryId).font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text(entryId).font(Theme.Typography.caption.monospaced()).foregroundStyle(colors.mutedFg)
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
                labelled("Label *") { TextField("Required", text: $label).textFieldStyle(.roundedBorder) }
            }
            labelled("Doc base path") { TextField("", text: $docBasePath).textFieldStyle(.roundedBorder) }
            labelled("Sections JSON *") {
                TextEditor(text: $sectionsJson).frame(minHeight: 200).font(.caption.monospaced()).border(colors.border).cornerRadius(4)
            }

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

    private func infoPanel(_ entry: FoundryKbEntry) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("INFO").font(Theme.Typography.caption2.weight(.semibold)).foregroundStyle(colors.mutedFg)
                infoRow("ID", entry.id, mono: true)
                infoRow("Course", entry.courseNameEn ?? entry.courseId)
                infoRow("Created", entry.createdAt)
            }
            .padding(Theme.Spacing.sm)
            .background(colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
        }
        .frame(width: 240)
    }

    private func save() async {
        saving = true; defer { saving = false }
        let body = FoundryKbUpdateBody(
            courseId: courseId,
            label: label.trimmingCharacters(in: .whitespaces),
            docBasePath: docBasePath.trimmedNil
        )
        let result = await state.update(entryId, body)
        toast = result != nil ? .success("Entry saved") : .error(state.error ?? "Save failed")
    }
}
