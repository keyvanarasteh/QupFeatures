import AdminAPI
import DesignSystem
import Networking
import ProjectsAPI
import SwiftUI

/// Helper surfaced from `ProjectDetailView` for the project-scoped
/// linked-account tooling that exists in q-hpc-panel.
///
/// The source helper can complete a repo-owner fix: create the GitHub linked
/// account on the diagnosed candidate user and add/update that user as a
/// project member using the selected project role.
public struct ProjectRepoOwnerHelperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors

    let project: Project
    let client: APIClient

    @State private var linkSeed: ProjectRepoOwnerLinkSeed?

    public init(project: Project, client: APIClient) {
        self.project = project
        self.client = client
    }

    private var matchingIssue: RepoOwnerIssue? {
        state.repoOwnerDiagnostics?.issues.first(where: { $0.projectId == project.id })
    }

    public var body: some View {
        NavigationStack {
            PageContainer {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader(
                        "Repo Owner Helper",
                        subtitle: "Diagnose a GitHub repository owner, link it to the matching user, and add that user to project membership.",
                        systemImage: "link.badge.plus"
                    )

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            keyValue("Project", project.name)
                            keyValue("Repository", project.repositoryUrl ?? "—")
                            keyValue("Owner", project.ownerName ?? "—")
                            keyValue("Slug", project.slug)
                        }
                    }

                    if state.loading.diagnostics && state.repoOwnerDiagnostics == nil {
                        ProgressView("Loading diagnostics…")
                            .frame(maxWidth: .infinity)
                    } else if let issue = matchingIssue {
                        issueCard(issue)
                    } else if let diagnostics = state.repoOwnerDiagnostics {
                        CardView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("No repo-owner issue flagged for this project.")
                                    .font(Theme.Typography.bodyEmphasized)
                                    .foregroundStyle(colors.success)
                                Text("The current project is not present in the diagnostics output.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(colors.mutedFg)
                            }
                        }

                        summaryCard(diagnostics.summary)
                    } else if let error = state.error {
                        Text(error).foregroundStyle(colors.danger)
                    } else {
                        EmptyStateView(
                            title: "No diagnostics loaded",
                            message: "Run project diagnostics again to check owner links.",
                            systemImage: "link.badge.plus"
                        )
                    }
                }
            }
            .navigationTitle("Repo Owner Helper")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if state.repoOwnerDiagnostics == nil {
                await state.loadRepoOwnerDiagnostics()
            }
        }
        .sheet(item: $linkSeed) { seed in
            ProjectRepoOwnerLinkSheet(client: client, seed: seed)
        }
    }

    private func issueCard(_ issue: RepoOwnerIssue) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(
                    "Owner mismatch",
                    subtitle: "GitHub-linked project whose repo owner doesn't match a linked team member.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                keyValue("Detected owner", issue.owner ?? "—")
                keyValue("Candidates", issue.candidates.map(\.userName).joined(separator: ", "))
                if let repositoryUrl = issue.repositoryUrl {
                    keyValue("Repository URL", repositoryUrl)
                }
                if let ownerSeed = ProjectRepoOwnerLinkSeed(issue: issue, project: project) {
                    Button {
                        linkSeed = ownerSeed
                    } label: {
                        Label("Link owner and fix membership", systemImage: "link.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                if issue.candidates.isEmpty {
                    Text("No linked-account candidates are available for this repo owner.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
            }
        }
    }

    private func summaryCard(_ summary: RepoOwnerDiagnosticsSummary) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            HelperMetricCard(title: "Total", value: "\(summary.total)", symbol: "folder")
            HelperMetricCard(title: "GitHub", value: "\(summary.github)", symbol: "chevron.left.forwardslash.chevron.right")
            HelperMetricCard(title: "OK", value: "\(summary.ok)", symbol: "checkmark.circle", tone: .success)
            HelperMetricCard(title: "Missing", value: "\(summary.missing)", symbol: "exclamationmark.triangle", tone: .warning)
        }
    }

    private func keyValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
                .frame(width: 110, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(Theme.Typography.body)
                .foregroundStyle(colors.fg)
            Spacer()
        }
    }
}

struct ProjectRepoOwnerLinkSeed: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let username: String
    let displayName: String
    let profileUrl: String
    let email: String
    let userID: Int
    let projectID: Int

    init?(issue: RepoOwnerIssue, project: Project) {
        guard let owner = issue.owner?.trimmedGitHubHandle, !owner.isEmpty,
              let candidate = issue.candidates.first else { return nil }
        let projectName = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = projectName.isEmpty ? "Repo owner" : "\(projectName) repo owner"
        self.username = owner
        self.displayName = issue.name.isEmpty ? (project.ownerName ?? project.name) : issue.name
        self.profileUrl = "https://github.com/\(owner)"
        self.email = ""
        self.userID = candidate.userId
        self.projectID = project.id
    }
}

private struct ProjectRepoOwnerLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors
    @EnvironmentObject private var state: ProjectsState

    private let api: AdminAPI

    @State private var label: String
    @State private var username: String
    @State private var displayName: String
    @State private var profileUrl: String
    @State private var saving = false
    @State private var success = false
    @State private var errorMessage: String?
    @State private var roleID = 0

    private let targetUserID: Int
    private let projectID: Int

    init(client: APIClient, seed: ProjectRepoOwnerLinkSeed) {
        self.api = AdminAPI(client: client)
        _label = State(initialValue: seed.label)
        _username = State(initialValue: seed.username)
        _displayName = State(initialValue: seed.displayName)
        _profileUrl = State(initialValue: seed.profileUrl)
        targetUserID = seed.userID
        projectID = seed.projectID
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub link") {
                    TextField("Label", text: $label)
                    TextField("Username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Display name", text: $displayName)
                    TextField("Profile URL", text: $profileUrl)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                }
                Section("Project membership") {
                    Picker("Role", selection: $roleID) {
                        Text("Select a role").tag(0)
                        ForEach(state.roles) { Text($0.displayName).tag($0.id) }
                    }
                }
                Section {
                    Text("The link is created for the diagnosed user, then that user is added to this project with the selected role.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(colors.danger)
                    }
                }
                if success {
                    Section {
                        Label("Linked account created", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(colors.success)
                    }
                }
            }
            .navigationTitle("Repo Owner Fix")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fix") { Task { await create() } }
                        .disabled(!canSave || roleID == 0 || saving)
                }
            }
        }
    }

    private func create() async {
        saving = true
        defer { saving = false }
        errorMessage = nil
        do {
            _ = try await api.createLinkedAccount(forUserID: targetUserID, LinkedAccountCreate(
                provider: LinkedAccountProvider.github.rawValue,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                profileUrl: profileUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                verified: false
            ))
            guard await state.addMember(projectId: projectID, userId: targetUserID, roleId: roleID) else {
                errorMessage = state.error ?? "The linked account was created, but project membership could not be updated."
                return
            }
            success = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}

private struct HelperMetricCard: View {
    @Environment(\.cupertinoColors) private var colors

    let title: String
    let value: String
    let symbol: String
    var tone: StatusTone = .neutral

    var body: some View {
        CardView(padding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Image(systemName: symbol)
                    .foregroundStyle(tone.color(in: colors))
                Text(value)
                    .font(Theme.Typography.title)
                    .foregroundStyle(tone == .neutral ? colors.fg : tone.color(in: colors))
                Text(title.uppercased())
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(colors.mutedFg)
            }
        }
    }
}

private extension String {
    var trimmedGitHubHandle: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingLeadingPrefix("@")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func trimmingLeadingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    var nilIfEmpty: String? { isEmpty ? nil : self }
}
