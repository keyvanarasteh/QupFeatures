import DesignSystem
import FoundryAPI
import SwiftUI

struct CourseCreateView: View {
    @EnvironmentObject private var state: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var id = ""
    @State private var nameEn = ""
    @State private var nameTr = ""
    @State private var descriptionEn = ""
    @State private var descriptionTr = ""
    @State private var icon = ""
    @State private var year = ""
    @State private var semester = ""
    @State private var courseCode = ""
    @State private var oisCode = ""
    @State private var meduCode = ""
    @State private var blackboardCode = ""
    @State private var metaJson = ""
    @State private var saving = false

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if let error = state.error { errorView(error) }
                form
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("New course").font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text("Create a new Foundry course definition.").font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            }
            Spacer()
        }
    }

    private var form: some View {
        VStack(spacing: Theme.Spacing.md) {
            labelled("Course ID *") {
                TextField("e.g. dsq-2026", text: $id).textFieldStyle(.roundedBorder)
                Text("Slug-like identifier, used as FK throughout the system. Cannot be changed later.")
                    .font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
            }
            HStack {
                labelled("Name (English) *") { TextField("DSQ Neural 2026", text: $nameEn).textFieldStyle(.roundedBorder) }
                labelled("Name (Turkish) *") { TextField("DSQ Neural 2026", text: $nameTr).textFieldStyle(.roundedBorder) }
            }
            labelled("Description (EN)") { TextEditor(text: $descriptionEn).frame(height: 60).border(colors.border).cornerRadius(4) }
            labelled("Description (TR)") { TextEditor(text: $descriptionTr).frame(height: 60).border(colors.border).cornerRadius(4) }
            labelled("Icon") { TextField("e.g. brain or icon-name", text: $icon).textFieldStyle(.roundedBorder) }
            HStack {
                labelled("Year") { TextField("2025-2026", text: $year).textFieldStyle(.roundedBorder) }
                labelled("Semester") { TextField("0-16", text: $semester).textFieldStyle(.roundedBorder) }
                labelled("Course code") { TextField("CMSE 456", text: $courseCode).textFieldStyle(.roundedBorder) }
            }
            HStack {
                labelled("OIS code") { TextField("", text: $oisCode).textFieldStyle(.roundedBorder).font(.caption.monospaced()) }
                labelled("Medu code") { TextField("", text: $meduCode).textFieldStyle(.roundedBorder).font(.caption.monospaced()) }
                labelled("Blackboard") { TextField("", text: $blackboardCode).textFieldStyle(.roundedBorder).font(.caption.monospaced()) }
            }
            labelled("Meta") { TextEditor(text: $metaJson).frame(height: 80).font(.caption.monospaced()).border(colors.border).cornerRadius(4) }

            HStack {
                Spacer()
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { dismiss() }
                    .tint(colors.mutedFg)
                CupertinoPrimaryButton("Create course", systemImage: "checkmark", expands: false) { Task { await create() } }
                    .disabled(saving || id.isEmpty || nameEn.isEmpty || nameTr.isEmpty)
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
        let body = FoundryCourseCreateBody(
            id: id.trimmingCharacters(in: .whitespaces),
            nameEn: nameEn.trimmingCharacters(in: .whitespaces),
            nameTr: nameTr.trimmingCharacters(in: .whitespaces),
            descriptionEn: descriptionEn.trimmedNil,
            descriptionTr: descriptionTr.trimmedNil,
            icon: icon.trimmedNil,
            year: year.trimmedNil,
            semester: Int(semester),
            courseCode: courseCode.trimmedNil,
            oisCode: oisCode.trimmedNil,
            meduCode: meduCode.trimmedNil,
            blackboardCode: blackboardCode.trimmedNil,
            meta: nil
        )
        let result = await state.create(body)
        if result != nil { dismiss() }
    }
}
