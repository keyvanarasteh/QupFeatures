import DesignSystem
import Networking
import ProjectsAPI
import SwiftUI

/// Native port of `routes/projects/sync/+page.svelte`: loads core-api's
/// two-phase GitHub account sync plan and writes each approved inferred link
/// through `POST /api/github?action=link_inferred_account`.
public struct ProjectsSyncSheet: View {
    private enum ItemStatus: Equatable {
        case pending, running, done, skipped, failed(String)

        var isProcessed: Bool {
            switch self {
            case .done, .skipped, .failed: true
            case .pending, .running: false
            }
        }
    }

    private struct Item: Identifiable {
        let candidate: ProjectGitHubSyncCandidate
        var status: ItemStatus = .pending
        var result: ProjectGitHubLinkResult?
        var id: String { candidate.id }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors

    private let api: ProjectsAPI
    @State private var items: [Item] = []
    @State private var loading = false
    @State private var running = false
    @State private var paused = false
    @State private var errorMessage: String?
    @State private var runTask: Task<Void, Never>?

    public init(client: APIClient) {
        self.api = ProjectsAPI(client: client)
    }

    private var processed: Int { items.filter { $0.status.isProcessed }.count }
    private var pending: Int { items.filter { $0.status == .pending }.count }
    private var done: Int { items.filter { $0.status == .done }.count }
    private var skipped: Int { items.filter { $0.status == .skipped }.count }
    private var failures: Int { items.filter { if case .failed = $0.status { true } else { false } }.count }
    private var progress: Double { items.isEmpty ? 0 : Double(processed) / Double(items.count) }

    public var body: some View {
        NavigationStack {
            PageContainer {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader(
                        "Sync GitHub Accounts",
                        subtitle: "Links cached GitHub identities first, then accounts inferred from single-member project repository URLs.",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    controls
                    if let errorMessage { Text(errorMessage).foregroundStyle(colors.danger) }
                    if loading {
                        ProgressView("Loading sync plan…").frame(maxWidth: .infinity)
                    } else if items.isEmpty {
                        EmptyStateView(
                            title: "Everything is linked",
                            message: "No cached or inferred GitHub accounts need a linked-account record.",
                            systemImage: "checkmark.circle"
                        )
                    } else {
                        phase("Cached GitHub data", source: .githubData)
                        phase("Inferred from project URLs", source: .inferred)
                    }
                }
            }
            .navigationTitle("GitHub Sync")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { stop(); dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await loadPlan() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(loading || running)
                }
            }
        }
        .task { await loadPlan() }
        .onDisappear { stop() }
    }

    private var controls: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    if running {
                        Button(paused ? "Resume" : "Pause", systemImage: paused ? "play" : "pause") { paused.toggle() }
                        Button("Stop", systemImage: "stop", role: .destructive) { stop() }
                    } else {
                        Button(processed > 0 ? "Continue" : "Start", systemImage: "play") { start() }
                            .disabled(pending == 0)
                        if processed > 0 {
                            Button("Reset", systemImage: "arrow.counterclockwise") { reset() }
                        }
                        if failures > 0 {
                            Button("Retry Errors", systemImage: "exclamationmark.arrow.circlepath") { retryErrors() }
                        }
                    }
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%").monospacedDigit()
                }
                ProgressView(value: progress)
                HStack {
                    counter("Done", done, .success)
                    counter("Skipped", skipped, .neutral)
                    counter("Errors", failures, .warning)
                    counter("Pending", pending, .info)
                }
            }
        }
    }

    private func counter(_ label: String, _ value: Int, _ tone: StatusTone) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Text("\(value)").font(Theme.Typography.bodyEmphasized).foregroundStyle(tone.color(in: colors))
            Text(label).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
        }
    }

    @ViewBuilder
    private func phase(_ title: String, source: ProjectGitHubSyncSource) -> some View {
        let phaseItems = items.filter { $0.candidate.source == source }
        if !phaseItems.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader("\(title) (\(phaseItems.count))")
                CardView(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(phaseItems.enumerated()), id: \.element.id) { index, item in
                            itemRow(item)
                            if index != phaseItems.count - 1 { SoftDivider() }
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            statusIcon(item.status)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(item.candidate.userName).font(Theme.Typography.bodyEmphasized)
                Text(item.candidate.email).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                if let project = item.candidate.projectName {
                    Label(project, systemImage: "folder").font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
                }
                if case let .failed(message) = item.status {
                    Text(message).font(Theme.Typography.caption2).foregroundStyle(colors.danger)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(item.result?.githubLogin ?? item.candidate.githubLogin)
                    .font(.system(.caption, design: .monospaced))
                if item.candidate.source == .inferred && item.status == .done {
                    Text("unverified").font(Theme.Typography.caption2).foregroundStyle(colors.warning)
                }
            }
            if let url = URL(string: "https://github.com/\(item.candidate.githubLogin)") {
                Link(destination: url) { Image(systemName: "arrow.up.right.square") }
            }
        }
        .padding(Theme.Spacing.md)
    }

    @ViewBuilder
    private func statusIcon(_ status: ItemStatus) -> some View {
        switch status {
        case .pending: Image(systemName: "clock").foregroundStyle(colors.mutedFg)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(colors.success)
        case .skipped: Image(systemName: "checkmark.circle").foregroundStyle(colors.mutedFg)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(colors.danger)
        }
    }

    @MainActor
    private func loadPlan() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            let plan = try await api.githubSyncPlan()
            items = (plan.phase1 + plan.phase2).map { Item(candidate: $0) }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func start() {
        guard !running else { return }
        running = true
        paused = false
        runTask = Task { @MainActor in
            for index in items.indices where items[index].status == .pending {
                while paused && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(150))
                }
                guard !Task.isCancelled, running else { break }
                items[index].status = .running
                let candidate = items[index].candidate
                do {
                    let result = try await api.linkInferredGitHubAccount(
                        userId: candidate.userId,
                        githubLogin: candidate.githubLogin
                    )
                    items[index].result = result
                    items[index].status = result.action == "already_linked" ? .skipped : .done
                } catch {
                    items[index].status = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            running = false
            paused = false
        }
    }

    private func stop() {
        running = false
        paused = false
        runTask?.cancel()
        runTask = nil
        for index in items.indices where items[index].status == .running { items[index].status = .pending }
    }

    private func reset() {
        stop()
        for index in items.indices { items[index].status = .pending; items[index].result = nil }
    }

    private func retryErrors() {
        for index in items.indices {
            if case .failed = items[index].status { items[index].status = .pending }
        }
        start()
    }
}
