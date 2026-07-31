import DesignSystem
import FoundryAPI
import SwiftUI

struct GradesView: View {
    @EnvironmentObject private var state: GradesState
    @EnvironmentObject private var courses: CoursesState
    @Environment(\.cupertinoColors) private var colors

    @State private var activeTab: GradeTab = .enrollments
    @State private var toast: Toast?

    enum GradeTab: String, CaseIterable {
        case enrollments = "Enrollments"
        case items = "Grade Items"
        case sheet = "Grade Sheet"
    }

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                filterBar
                termBadges
                if let toast { toastView(toast) }
                if let error = state.error { errorView(error) }
                tabPicker
                tabContent
            }
        }
        .task { await courses.loadList() }
    }

    private var filterBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Course").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                Picker("", selection: $state.selectedCourse) {
                    Text("— select —").tag("")
                    ForEach(courses.courses, id: \.id) { c in
                        Text(c.nameEn).tag(c.id)
                    }
                }
                .onChange(of: state.selectedCourse) { _, _ in applyFilter() }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Academic year").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                Picker("", selection: $state.selectedYear) {
                    Text("— select —").tag("")
                    ForEach(termYears, id: \.self) { y in Text(y).tag(y) }
                }
                .onChange(of: state.selectedYear) { _, _ in applyFilter() }
                .frame(width: 120)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Semester").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                Picker("", selection: $state.selectedSemester) {
                    Text("— select —").tag("")
                    ForEach(termSemesters, id: \.self) { s in Text(s).tag(s) }
                }
                .onChange(of: state.selectedSemester) { _, _ in applyFilter() }
                .frame(width: 100)
            }

            CupertinoPrimaryButton("Load", systemImage: "arrow.down.doc", expands: false) { applyFilter() }
                .disabled(state.selectedCourse.isEmpty)
        }
        .padding(Theme.Spacing.md)
        .background(colors.muted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private var termBadges: some View {
        Group {
            if !termCombos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Text("Existing:").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                        ForEach(termCombos, id: \.self) { combo in
                            let active = state.selectedCourse == combo.courseId && state.selectedYear == combo.year && state.selectedSemester == combo.semester
                            Button(combo.label) {
                                state.selectedCourse = combo.courseId
                                state.selectedYear = combo.year
                                state.selectedSemester = combo.semester
                                applyFilter()
                            }
                            .font(Theme.Typography.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(active ? colors.primary.opacity(0.1) : Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(active ? colors.primary : colors.border))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .enrollments: EnrollmentsTab()
        case .items: GradeItemsTab()
        case .sheet: GradeSheetTab()
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            ForEach(GradeTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterReady: Bool {
        !state.selectedCourse.isEmpty && !state.selectedYear.isEmpty && !state.selectedSemester.isEmpty
    }

    private func applyFilter() {
        guard !state.selectedCourse.isEmpty else { return }
        Task {
            async let _ = state.loadGradeItems(courseId: state.selectedCourse)
            async let _ = state.loadTerms(courseId: state.selectedCourse)
            if !state.selectedYear.isEmpty && !state.selectedSemester.isEmpty {
                _ = await state.loadEnrollments(courseId: state.selectedCourse, year: state.selectedYear, semester: state.selectedSemester)
            }
            if activeTab == .sheet && filterReady {
                await state.loadSheet(courseId: state.selectedCourse, year: state.selectedYear, semester: state.selectedSemester)
            }
        }
    }

    private var termYears: [String] {
        Array(Set(state.terms.map(\.academicYear))).sorted().reversed()
    }

    private var termSemesters: [String] {
        Array(Set(state.terms.map(\.semester))).sorted()
    }

    private var termCombos: [TermCombo] {
        guard !state.selectedCourse.isEmpty else { return [] }
        let filtered = state.terms.filter { $0.courseId == state.selectedCourse }
        return filtered.map { TermCombo(courseId: $0.courseId, year: $0.academicYear, semester: $0.semester, label: "\($0.courseName) · \($0.academicYear) · \($0.semester)") }
    }
}

struct TermCombo: Hashable, Identifiable {
    let courseId: String
    let year: String
    let semester: String
    let label: String
    var id: String { "\(courseId)-\(year)-\(semester)" }
}