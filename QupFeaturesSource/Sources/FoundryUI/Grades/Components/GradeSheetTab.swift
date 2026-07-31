import DesignSystem
import FoundryAPI
import SwiftUI

struct GradeSheetTab: View {
    @EnvironmentObject private var state: GradesState
    @Environment(\.cupertinoColors) private var colors

    @State private var showCheckup = false
    @State private var showProjectModal = false
    @State private var projectRosterId = 0
    @State private var projectGradeItemId = ""
    @State private var projectStudentName = ""
    @State private var projectItemLabel = ""
    @State private var editGradeItemId = ""
    @State private var editRosterId = 0
    @State private var editScore = ""
    @State private var toast: Toast?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let toast { toastView(toast) }
            if state.loading.sheet {
                ProgressView().frame(maxWidth: .infinity)
            } else if let sheet = state.sheet {
                HStack {
                    Text("\(sheet.students.count) students · \(sheet.items.count) items").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Spacer()
                    CupertinoPrimaryButton("Checkup", systemImage: "list.bullet.clipboard", expands: false) {
                        showCheckup = true
                    }
                }
                gradeSheetTable(sheet)
            } else {
                EmptyStateView(title: "No grade sheet", message: "Select course, year and semester, then tap Load.", systemImage: "tablecells")
            }
        }
        .sheet(isPresented: $showProjectModal) {
            GradeProjectModalView(
                rosterId: projectRosterId,
                gradeItemId: projectGradeItemId,
                studentName: projectStudentName,
                itemLabel: projectItemLabel
            )
        }
    }

    private func gradeSheetTable(_ sheet: FoundryGradeSheet) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                headerRow(sheet)
                studentRows(sheet)
            }
            .background(colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
        }
    }

    private func headerRow(_ sheet: FoundryGradeSheet) -> some View {
        HStack(spacing: 0) {
            Text("Student").font(Theme.Typography.caption2.weight(.semibold))
                .frame(width: 180, alignment: .leading).padding(Theme.Spacing.sm)
            ForEach(sheet.items, id: \.id) { item in
                Text(item.label).font(Theme.Typography.caption2.weight(.semibold))
                    .frame(width: 100).padding(Theme.Spacing.sm)
            }
        }
        .background(colors.muted.opacity(0.3))
    }

    private func studentRows(_ sheet: FoundryGradeSheet) -> some View {
        ForEach(sheet.students, id: \.studentId) { student in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(student.studentName).font(Theme.Typography.caption).foregroundStyle(colors.fg)
                    Text(student.studentNo).font(Theme.Typography.caption2.monospaced()).foregroundStyle(colors.mutedFg)
                }
                .frame(width: 180, alignment: .leading).padding(Theme.Spacing.sm)

                ForEach(sheet.items, id: \.id) { item in
                    let cell = student.grades[item.id]
                    gradeCell(student: student, item: item, cell: cell)
                        .frame(width: 100).padding(Theme.Spacing.xs)
                }
            }
            if student.studentId != sheet.students.last?.studentId {
                SoftDivider()
            }
        }
    }

    private func gradeCell(student: FoundryGradeSheetStudent, item: FoundryGradeItem, cell: FoundryGradeCell?) -> some View {
        HStack(spacing: 2) {
            if let cell {
                Text(cell.score.map { String(Int($0)) } ?? "—").font(Theme.Typography.caption.monospaced())
                    .foregroundStyle(cell.score != nil ? colors.fg : colors.mutedFg)
                if cell.projectId != nil {
                    Image(systemName: "link").font(.system(size: 8)).foregroundStyle(colors.info)
                }
                Menu {
                    Button("Edit score") {
                        editGradeItemId = item.id
                        editRosterId = student.studentId
                        editScore = cell.score.map { String(Int($0)) } ?? ""
                    }
                    Button("Link project") {
                        projectRosterId = student.studentId
                        projectGradeItemId = item.id
                        projectStudentName = student.studentName
                        projectItemLabel = item.label
                        showProjectModal = true
                    }
                    if cell.projectId != nil {
                        Button("Unlink project", role: .destructive) {
                            Task {
                                let ok = await state.unlinkProject(rosterId: student.studentId, gradeItemId: item.id)
                                if ok { await state.loadSheet(courseId: state.selectedCourse, year: state.selectedYear, semester: state.selectedSemester) }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 8))
                        .foregroundStyle(colors.mutedFg)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
            } else {
                Text("—").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            }
        }
    }
}
