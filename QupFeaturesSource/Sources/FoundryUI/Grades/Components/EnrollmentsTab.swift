import DesignSystem
import FoundryAPI
import SwiftUI

struct EnrollmentsTab: View {
    @EnvironmentObject private var state: GradesState
    @Environment(\.cupertinoColors) private var colors
    @State private var showEnrollForm = false
    @State private var enrollStudentId = ""
    @State private var toast: Toast?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("\(state.enrollments.count) enrolled").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                Spacer()
                if isFiltered {
                    CupertinoPrimaryButton("+ Enroll student", systemImage: "person.badge.plus", expands: false) {
                        showEnrollForm = true
                    }
                }
            }

            if state.loading.list {
                ProgressView().frame(maxWidth: .infinity)
            } else if state.enrollments.isEmpty {
                EmptyStateView(title: "No enrollments", message: isFiltered ? "No enrollments for this term." : "Select course, year and semester above.", systemImage: "person.2")
            } else {
                listTable
            }
        }
        .sheet(isPresented: $showEnrollForm) {
            enrollFormSheet
        }
    }

    private var isFiltered: Bool {
        !state.selectedCourse.isEmpty && !state.selectedYear.isEmpty && !state.selectedSemester.isEmpty
    }

    private var listTable: some View {
        VStack(spacing: 0) {
            ForEach(state.enrollments, id: \.id) { en in
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(en.studentName).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.fg)
                        HStack {
                            Text(en.studentNo).font(Theme.Typography.caption2.monospaced()).foregroundStyle(colors.mutedFg)
                            Text(en.program).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                        }
                    }
                    Spacer()
                    Text(en.academicYear).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                    Text(en.semester).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                    StatusBadge(en.status, tone: statusTone(en.status))
                    Button(role: .destructive) {
                        Task {
                            let ok = await state.unenrollStudent(id: en.id)
                            if ok {
                                await state.loadEnrollments(courseId: state.selectedCourse, year: state.selectedYear, semester: state.selectedSemester)
                            }
                        }
                    } label: { Text("Remove").font(Theme.Typography.caption2) }
                        .buttonStyle(.bordered).tint(colors.danger)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                if en.id != state.enrollments.last?.id { SoftDivider() }
            }
        }
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private var enrollFormSheet: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Enroll student").font(Theme.Typography.title3).foregroundStyle(colors.fg)
            Text("\(state.selectedCourse) · \(state.selectedYear) · \(state.selectedSemester)")
                .font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)

            labelled("Student ID") {
                TextField("e.g. 42", text: $enrollStudentId).textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            if let error = state.error {
                Text(error).font(Theme.Typography.caption).foregroundStyle(colors.danger)
            }

            HStack {
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { showEnrollForm = false }
                    .tint(colors.mutedFg)
                CupertinoPrimaryButton("Enroll", systemImage: "checkmark", expands: false) {
                    Task {
                        guard let sid = Int(enrollStudentId) else { return }
                        let id = await state.enrollStudent(courseId: state.selectedCourse, studentId: sid, year: state.selectedYear, semester: state.selectedSemester)
                        if id != nil {
                            showEnrollForm = false
                            enrollStudentId = ""
                            await state.loadEnrollments(courseId: state.selectedCourse, year: state.selectedYear, semester: state.selectedSemester)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.xl)
    }

    private func statusTone(_ status: String) -> StatusTone {
        switch status {
        case "enrolled": .success
        case "withdrawn": .danger
        case "completed": .info
        default: .neutral
        }
    }
}
