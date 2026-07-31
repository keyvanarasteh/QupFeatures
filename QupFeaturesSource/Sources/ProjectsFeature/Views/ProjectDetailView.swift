import DesignSystem
import FeatureContracts
import ProjectsAPI
import SwiftUI
import TasksAPI

/// Full native port of `[id]/+page.svelte` + `ProjectDetail.svelte` using the
/// existing core-api project update/member/stats/activity contracts and the
/// tasks endpoint's `project_id` filter. The debug-daemon-only local clone and
/// README operations remain deliberately excluded from this cross-platform
/// feature; the repository URL still opens in the system browser.
public struct ProjectDetailView: View {
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.openURL) private var openURL

    let context: FeatureContext
    let projectId: Int
    let onBack: () -> Void
    let readOnly: Bool

    @State private var ownerHelpOpen = false
    @State private var editorOpen = false
    @State private var memberOpen = false
    @State private var confirmDelete = false

    public init(context: FeatureContext, projectId: Int, readOnly: Bool = false, onBack: @escaping () -> Void) {
        self.context = context
        self.projectId = projectId
        self.onBack = onBack
        self.readOnly = readOnly
    }

    private var project: Project? { state.currentProject?.id == projectId ? state.currentProject : nil }

    public var body: some View {
        PageContainer {
            if state.loading.project && project == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = state.error, project == nil {
                Text(error).foregroundStyle(colors.danger)
            } else if let project {
                content(for: project)
            } else {
                EmptyStateView(title: "Project not found", message: "It may have been deleted.", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle("Project")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    onBack()
                } label: {
                    Label("Back to Projects", systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Theme.Spacing.xs) {
                    if project != nil && !readOnly {
                        Button { editorOpen = true } label: { Image(systemName: "pencil") }
                        Button { memberOpen = true } label: { Image(systemName: "person.badge.plus") }
                        Button {
                            ownerHelpOpen = true
                        } label: {
                            Image(systemName: "link.badge.plus")
                        }
                    }
                    Button {
                        Task { await state.loadProject(id: projectId) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await state.loadProject(id: projectId) }
        .sheet(isPresented: $ownerHelpOpen) {
            if let project {
                ProjectRepoOwnerHelperSheet(project: project, client: context.qlineClient)
            }
        }
        .sheet(isPresented: $editorOpen) {
            if let project { ProjectEditorSheet(project: project) }
        }
        .sheet(isPresented: $memberOpen) {
            if let project { ProjectMemberSheet(project: project, client: context.qlineClient) }
        }
        .confirmationDialog("Delete project?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    if await state.deleteProject(id: projectId) { onBack() }
                }
            }
        } message: {
            Text("This permanently removes the project.")
        }
    }

    @ViewBuilder
    private func content(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header(for: project)

            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let description = project.description, !description.isEmpty {
                        SectionHeader("Description")
                        Text(description).font(Theme.Typography.body).foregroundStyle(colors.fg)
                    }

                    if let tags = project.tags, !tags.isEmpty {
                        SectionHeader("Tags")
                        HStack {
                            ForEach(tags, id: \.self) { CupertinoChip($0) }
                        }
                    }

                    SectionHeader("Details")
                    detailGrid(for: project)
                }
            }

            stackSection(project)
            deploymentSection(project)
            statsSection
            membersSection(project)
            linkedAccountsSection
            linkedTasksSection
            activitySection

            if !readOnly {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Project", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func header(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(project.name).font(Theme.Typography.title).foregroundStyle(colors.fg)
                if !project.isActive {
                    StatusBadge("Inactive", tone: .neutral)
                }
                Image(systemName: project.isPrivate ? "lock.fill" : "globe")
                    .foregroundStyle(colors.mutedFg)
                if let statusDisplay = project.statusDisplay {
                    StatusBadge(statusDisplay, tone: .info)
                }
                Spacer()
            }
            Text(project.slug).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
        }
    }

    private func detailGrid(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let typeDisplay = project.typeDisplay {
                detailRow("Type", typeDisplay)
            }
            if let language = project.programmingLanguage {
                detailRow("Language", language)
            }
            if let framework = project.framework {
                detailRow("Framework", framework)
            }
            if let version = project.version {
                detailRow("Project version", version)
            }
            if let branch = project.defaultBranch {
                detailRow("Default branch", branch)
            }
            if let repositoryUrl = project.repositoryUrl, let url = URL(string: repositoryUrl) {
                HStack {
                    Text("Repository").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Spacer()
                    Button(repositoryUrl) { openURL(url) }
                        .buttonStyle(.plain)
                        .foregroundStyle(colors.primary)
                        .lineLimit(1)
                }
            }
            if let ownerName = project.ownerName {
                detailRow("Owner", ownerName)
            }
            if let memberCount = project.memberCount {
                detailRow("Members", "\(memberCount)")
            }
            detailRow("Created", project.createdAt)
            detailRow("Updated", project.updatedAt)
        }
    }

    @ViewBuilder
    private func stackSection(_ project: Project) -> some View {
        let values = project.techStack ?? []
        if !values.isEmpty || project.programmingLanguage != nil || project.framework != nil || project.packageManager != nil {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Technology Stack", systemImage: "chevron.left.forwardslash.chevron.right")
                    if !values.isEmpty {
                        HStack { ForEach(values, id: \.self) { CupertinoChip($0) } }
                    }
                    if let language = project.programmingLanguage {
                        detailRow("Language", joined(language, project.languageVersion))
                    }
                    if let framework = project.framework {
                        detailRow("Framework", joined(framework, project.frameworkVersion))
                    }
                    if let packageManager = project.packageManager {
                        detailRow("Package manager", joined(packageManager, project.packageManagerVersion))
                    }
                    if let confidence = project.confidenceScore {
                        detailRow("Detection confidence", "\(confidence)%")
                    }
                    runtimeRows(project)
                    directoryRows(project)
                }
            }
        }
    }

    @ViewBuilder
    private func runtimeRows(_ project: Project) -> some View {
        let runtimes = [
            ("Node", project.nodeVersion), ("Python", project.pythonVersion),
            ("Rust", project.rustVersion), ("Go", project.goVersion),
            ("Java", project.javaVersion), ("PHP", project.phpVersion),
            ("Ruby", project.rubyVersion),
        ]
        ForEach(runtimes.filter { $0.1 != nil }, id: \.0) { item in
            detailRow("\(item.0) runtime", item.1 ?? "")
        }
    }

    @ViewBuilder
    private func directoryRows(_ project: Project) -> some View {
        let directories = [
            ("Root", project.rootDirectory), ("Source", project.sourceDirectory),
            ("Output", project.outputDirectory), ("Public", project.publicDirectory),
        ]
        ForEach(directories.filter { $0.1 != nil }, id: \.0) { item in
            detailRow("\(item.0) directory", item.1 ?? "")
        }
    }

    @ViewBuilder
    private func deploymentSection(_ project: Project) -> some View {
        let commands = [
            ("Install", project.installCommand), ("Build", project.buildCommand),
            ("Start", project.startCommand), ("Development", project.devCommand),
            ("Test", project.testCommand), ("Lint", project.lintCommand),
        ]
        if project.autoDeploy == true || project.deployOnPush == true || project.deployBranch != nil
            || commands.contains(where: { $0.1 != nil }) || project.productionUrl != nil
            || project.stagingUrl != nil || project.previewUrl != nil {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Build & Deployment", systemImage: "shippingbox")
                    detailRow("Auto deploy", project.autoDeploy == true ? "Enabled" : "Disabled")
                    detailRow("Deploy on push", project.deployOnPush == true ? "Enabled" : "Disabled")
                    if let branch = project.deployBranch { detailRow("Deploy branch", branch) }
                    ForEach(commands.filter { $0.1 != nil }, id: \.0) { command in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("\(command.0) command").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                            Text(command.1 ?? "").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    externalURLRow("Production", project.productionUrl)
                    externalURLRow("Staging", project.stagingUrl)
                    externalURLRow("Preview", project.previewUrl)
                }
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats = state.projectStats {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Project Stats", systemImage: "chart.bar")
                    HStack {
                        metric("Tasks", "\(stats.taskCount)")
                        metric("Done", "\(stats.doneCount)")
                        metric("Completion", "\(Int(stats.completion.rounded()))%")
                        metric("Progress", "\(Int(stats.avgProgress.rounded()))%")
                        metric("Members", "\(stats.memberCount)")
                    }
                }
            }
        }
    }

    private func membersSection(_ project: Project) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    SectionHeader("Members", systemImage: "person.2")
                    Spacer()
                    if !readOnly {
                        Button { memberOpen = true } label: { Label("Add", systemImage: "plus") }
                    }
                }
                if (project.members ?? []).isEmpty {
                    Text("No collaborators are assigned.").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                } else {
                    ForEach(project.members ?? []) { member in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(member.name).font(Theme.Typography.bodyEmphasized)
                                Text(member.email ?? "").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                            }
                            Spacer()
                            StatusBadge(member.roleDisplay ?? "", tone: .info)
                            if !readOnly {
                                Button(role: .destructive) {
                                    Task { _ = await state.removeMember(projectId: project.id, userId: member.userId) }
                                } label: { Image(systemName: "person.badge.minus") }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Collaborator identities (e.g. GitHub handles) for every project member
    /// — `ProjectsState.loadLinkedAccounts` mirrors
    /// `ProjectLinkedAccountController`'s per-user grouping, including its
    /// owner-fallback `member` entry that may have no name/email.
    @ViewBuilder
    private var linkedAccountsSection: some View {
        if !state.linkedAccounts.isEmpty {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Linked Accounts", systemImage: "link")
                    ForEach(state.linkedAccounts) { entry in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(entry.member?.name ?? "User #\(entry.userId)")
                                .font(Theme.Typography.bodyEmphasized)
                                .foregroundStyle(colors.fg)
                            if entry.accounts.isEmpty {
                                Text("No linked accounts").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                            } else {
                                ForEach(entry.accounts) { account in
                                    HStack {
                                        Text(account.provider.capitalized).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                                        Text(account.username ?? account.label).font(Theme.Typography.caption)
                                        if account.verified {
                                            Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(colors.success)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linkedTasksSection: some View {
        if !state.linkedTasks.isEmpty {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Linked Tasks", systemImage: "checklist")
                    ForEach(state.linkedTasks) { task in
                        HStack {
                            Image(systemName: task.status.systemImage).foregroundStyle(colors.primary)
                            VStack(alignment: .leading) {
                                Text(task.title).font(Theme.Typography.bodyEmphasized)
                                Text("\(task.priority.title) · \(task.progress)%")
                                    .font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                            }
                            Spacer()
                            StatusBadge(task.status.title, tone: task.status == .done ? .success : .info)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if !state.projectActivity.isEmpty {
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader("Activity", systemImage: "clock.arrow.circlepath")
                    ForEach(state.projectActivity) { item in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(colors.primary).padding(.top, 6)
                            VStack(alignment: .leading) {
                                Text(item.description ?? item.activityAction).font(Theme.Typography.body)
                                Text([item.userName, item.createdAt].compactMap { $0 }.joined(separator: " · "))
                                    .font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                            }
                        }
                    }
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(Theme.Typography.title)
            Text(label).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func externalURLRow(_ label: String, _ value: String?) -> some View {
        if let value, let url = URL(string: value) {
            HStack {
                Text(label).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                Spacer()
                Button(value) { openURL(url) }.buttonStyle(.plain).foregroundStyle(colors.primary).lineLimit(1)
            }
        }
    }

    private func joined(_ name: String, _ version: String?) -> String {
        [name, version].compactMap { $0 }.joined(separator: " ")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            Spacer()
            Text(value).font(Theme.Typography.caption).foregroundStyle(colors.fg)
        }
    }
}
