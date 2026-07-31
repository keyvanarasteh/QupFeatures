import DesignSystem
import FoundryAPI
import SwiftUI

struct GradeProjectModalView: View {
    @EnvironmentObject private var state: GradesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let rosterId: Int
    let gradeItemId: String
    let studentName: String
    let itemLabel: String

    @State private var projects: [FoundryLinkableProject] = []
    @State private var loadingList = true
    @State private var selectedId: Int?
    @State private var toast: Toast?

    private var isLinked: Bool { selectedId != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            header
            if let toast { toastView(toast) }
            if let error = state.error { errorView(error) }

            if loadingList {
                ProgressView()
            } else if projects.isEmpty {
                EmptyStateView(title: "No projects", message: "No linkable projects found for this student.", systemImage: "folder")
            } else {
                projectList
            }

            HStack(spacing: Theme.Spacing.md) {
                CupertinoPrimaryButton("Cancel", systemImage: "xmark", expands: false) { dismiss() }
                    .tint(colors.mutedFg)

                CupertinoPrimaryButton("Unlink", systemImage: "link.slash", expands: false) {
                    Task {
                        let ok = await state.unlinkProject(rosterId: rosterId, gradeItemId: gradeItemId)
                        if ok { dismiss() }
                    }
                }
                .disabled(!isLinked)
                .tint(colors.danger)

                CupertinoPrimaryButton("Link", systemImage: "link", expands: false) {
                    guard let pid = selectedId else { return }
                    Task {
                        let ok = await state.linkProject(rosterId: rosterId, gradeItemId: gradeItemId, projectId: pid)
                        if ok { dismiss() }
                    }
                }
                .disabled(selectedId == nil)
            }
        }
        .padding(Theme.Spacing.xl)
        .task {
            projects = await state.linkableProjects(rosterId: rosterId)
            loadingList = false
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Link project").font(Theme.Typography.title3.weight(.semibold)).foregroundStyle(colors.fg)
            Text(studentName).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            Text(itemLabel).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
        }
    }

    private var projectList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(projects, id: \.id) { project in
                    Button {
                        selectedId = selectedId == project.id ? nil : project.id
                    } label: {
                        HStack {
                            if let icon = project.typeIcon {
                                Image(systemName: icon).foregroundStyle(project.typeColor.map { Color(hex: $0) } ?? colors.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name).font(Theme.Typography.body.weight(.medium)).foregroundStyle(colors.fg)
                                HStack {
                                    if let td = project.typeDisplay { Text(td).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg) }
                                    if let mc = project.memberCount { Text("\(mc) members").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg) }
                                }
                            }
                            Spacer()
                            if project.id == selectedId {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(colors.primary)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.md)
                        .background(project.id == selectedId ? colors.primary.opacity(0.05) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    if project.id != projects.last?.id { SoftDivider() }
                }
            }
            .background(colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
        }
        .frame(maxHeight: 300)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self = Color(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}
