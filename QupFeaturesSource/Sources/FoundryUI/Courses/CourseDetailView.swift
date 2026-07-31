import DesignSystem
import FoundryAPI
import SwiftUI

struct CourseDetailView: View {
    @EnvironmentObject private var state: CoursesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let courseId: String

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
                } else if let course = state.current {
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        formView(course)
                        infoPanel(course)
                    }
                } else {
                    EmptyStateView(title: "Not found", message: "Course not found.", systemImage: "questionmark")
                }
            }
        }
        .task { await state.loadOne(courseId) }
        .onChange(of: state.current) { _, course in
            guard let c = course else { return }
            nameEn = c.nameEn; nameTr = c.nameTr
            descriptionEn = c.descriptionEn ?? ""; descriptionTr = c.descriptionTr ?? ""
            icon = c.icon ?? ""; year = c.year ?? ""; semester = c.semester.map(String.init) ?? ""
            courseCode = c.courseCode ?? ""; oisCode = c.oisCode ?? ""; meduCode = c.meduCode ?? ""
            blackboardCode = c.blackboardCode ?? ""
            metaJson = c.meta.map { String(describing: $0) } ?? ""
        }
        .alert("Delete course?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await state.remove(courseId)
                    if ok { dismiss() }
                    else { toast = .error(state.error ?? "Delete failed") }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(state.current?.nameEn ?? courseId).font(Theme.Typography.title).foregroundStyle(colors.fg)
                Text(courseId).font(Theme.Typography.caption.monospaced()).foregroundStyle(colors.mutedFg)
            }
            Spacer()
            Button(role: .destructive) { confirmDelete = true } label: { Text("Delete").font(Theme.Typography.caption) }
                .buttonStyle(.bordered).tint(colors.danger)
        }
    }

    private func formView(_ course: FoundryCourse) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Group {
                labelled("Name (English) *") { TextField("Required", text: $nameEn).textFieldStyle(.roundedBorder) }
                labelled("Name (Turkish) *") { TextField("Required", text: $nameTr).textFieldStyle(.roundedBorder) }
                labelled("Description (EN)") { TextEditor(text: $descriptionEn).frame(height: 60).border(colors.border).cornerRadius(4) }
                labelled("Description (TR)") { TextEditor(text: $descriptionTr).frame(height: 60).border(colors.border).cornerRadius(4) }
                labelled("Icon") { TextField("e.g. brain or icon-name", text: $icon).textFieldStyle(.roundedBorder) }
            }
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
            labelled("Meta") { TextEditor(text: $metaJson).frame(height: 100).font(.caption.monospaced()).border(colors.border).cornerRadius(4) }

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

    private func infoPanel(_ course: FoundryCourse) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("INFO").font(Theme.Typography.caption2.weight(.semibold)).foregroundStyle(colors.mutedFg)
                infoRow("ID", course.id, mono: true)
                infoRow("Year", course.year ?? "—")
                infoRow("Semester", course.semester.map(String.init) ?? "—")
                infoRow("Course code", course.courseCode ?? "—", mono: true)
                infoRow("OIS", course.oisCode ?? "—", mono: true)
                infoRow("MEDU", course.meduCode ?? "—", mono: true)
                infoRow("Blackboard", course.blackboardCode ?? "—", mono: true)
                infoRow("Created", course.createdAt)
                infoRow("Updated", course.updatedAt)
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
        let body = FoundryCourseUpdateBody(
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
        let result = await state.update(courseId, body)
        toast = result != nil ? .success("Course saved") : .error(state.error ?? "Save failed")
    }
}

extension String {
    var trimmedNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
