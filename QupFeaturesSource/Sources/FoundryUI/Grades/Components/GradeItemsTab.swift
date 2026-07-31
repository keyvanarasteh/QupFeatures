import DesignSystem
import FoundryAPI
import SwiftUI

struct GradeItemsTab: View {
    @EnvironmentObject private var state: GradesState
    @Environment(\.cupertinoColors) private var colors

    @State private var showForm = false
    @State private var editingItemId: String?
    @State private var formType = "midterm"
    @State private var formLabel = ""
    @State private var formMaxScore = 100.0
    @State private var formWeight = 0.0
    @State private var formOrderIndex = 0
    @State private var formRubricRef = ""
    @State private var toast: Toast?

    private let itemTypes = ["midterm", "final", "homework", "extra"]
    private let typeLabels = ["midterm": "Midterm", "final": "Final", "homework": "Homework", "extra": "Extra"]
    private let typeColors: [String: Color] = [
        "midterm": .blue, "final": .purple, "homework": .orange, "extra": .green
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("\(state.gradeItems.count) grade item\(state.gradeItems.count == 1 ? "" : "s")").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                Spacer()
                if !state.selectedCourse.isEmpty {
                    CupertinoPrimaryButton("+ Add item", systemImage: "plus", expands: false) {
                        editingItemId = nil
                        formType = "midterm"; formLabel = ""; formMaxScore = 100; formWeight = 0
                        formOrderIndex = state.gradeItems.count; formRubricRef = ""
                        showForm = true
                    }
                }
            }

            if state.loading.list {
                ProgressView().frame(maxWidth: .infinity)
            } else if state.gradeItems.isEmpty {
                EmptyStateView(title: "No grade items", message: state.selectedCourse.isEmpty ? "Select a course above." : "No grade items defined.", systemImage: "list.number")
            } else {
                itemsTable
            }
        }
        .sheet(isPresented: $showForm) { itemFormSheet }
    }

    private var itemsTable: some View {
        VStack(spacing: 0) {
            ForEach(state.gradeItems, id: \.id) { item in
                HStack(spacing: Theme.Spacing.sm) {
                    Text(item.type).font(Theme.Typography.caption2.weight(.medium))
                        .foregroundStyle(typeColors[item.type, default: colors.fg])
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(typeColors[item.type, default: colors.fg].opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.fg)
                        Text("max \(Int(item.maxScore)) · \(Int(item.weight))%").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                    }
                    Spacer()
                    Button { editItem(item) } label: { Text("Edit").font(Theme.Typography.caption2) }
                        .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        Task {
                            let ok = await state.deleteGradeItem(id: item.id)
                            if ok { await state.loadGradeItems(courseId: state.selectedCourse) }
                        }
                    } label: { Text("Delete").font(Theme.Typography.caption2) }
                        .buttonStyle(.bordered).tint(colors.danger)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                if item.id != state.gradeItems.last?.id { SoftDivider() }
            }
        }
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private var itemFormSheet: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(editingItemId != nil ? "Edit grade item" : "Add grade item").font(Theme.Typography.title3).foregroundStyle(colors.fg)

            if editingItemId == nil {
                labelled("Type") {
                    Picker("", selection: $formType) {
                        ForEach(itemTypes, id: \.self) { t in Text(typeLabels[t] ?? t).tag(t) }
                    }
                }
            }

            labelled("Label *") { TextField("e.g. Midterm Exam", text: $formLabel).textFieldStyle(.roundedBorder) }

            HStack {
                labelled("Max score") { TextField("", value: $formMaxScore, format: .number).textFieldStyle(.roundedBorder) }
                labelled("Weight %") { TextField("", value: $formWeight, format: .number).textFieldStyle(.roundedBorder) }
            }

            HStack {
                labelled("Order index") { TextField("", value: $formOrderIndex, format: .number).textFieldStyle(.roundedBorder) }
                labelled("Rubric ref") { TextField("optional", text: $formRubricRef).textFieldStyle(.roundedBorder) }
            }

            if let error = state.error {
                Text(error).font(Theme.Typography.caption).foregroundStyle(colors.danger)
            }

            HStack {
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { showForm = false }
                    .tint(colors.mutedFg)
                CupertinoPrimaryButton(editingItemId != nil ? "Update" : "Create", systemImage: "checkmark", expands: false) {
                    Task { await saveItem() }
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 400)
    }

    private func editItem(_ item: FoundryGradeItem) {
        editingItemId = item.id
        formType = item.type; formLabel = item.label
        formMaxScore = item.maxScore; formWeight = item.weight
        formOrderIndex = item.orderIndex; formRubricRef = item.rubricRef ?? ""
        showForm = true
    }

    private func saveItem() async {
        if let id = editingItemId {
            let body = FoundryGradeItemUpdateBody(label: formLabel, maxScore: formMaxScore, weight: formWeight, orderIndex: formOrderIndex, rubricRef: formRubricRef.isEmpty ? nil : formRubricRef)
            let ok = await state.updateGradeItem(id: id, body)
            if ok { showForm = false; await state.loadGradeItems(courseId: state.selectedCourse) }
        } else {
            let body = FoundryGradeItemCreateBody(courseId: state.selectedCourse, type: formType, label: formLabel, maxScore: formMaxScore, weight: formWeight, orderIndex: formOrderIndex, rubricRef: formRubricRef.isEmpty ? nil : formRubricRef)
            let id = await state.createGradeItem(body)
            if id != nil { showForm = false; await state.loadGradeItems(courseId: state.selectedCourse) }
        }
    }
}
