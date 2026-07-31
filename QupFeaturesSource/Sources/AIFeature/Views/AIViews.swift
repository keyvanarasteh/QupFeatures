import AIAPI
import SwiftUI

// MARK: - Overview Dashboard (q-hpc-panel style card grid)
struct AIOverviewView: View {
    @EnvironmentObject private var state: AIState
    @Binding var section: AISection

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .frame(width: 32, height: 32)
                        .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Lab")
                            .font(.title2).fontWeight(.bold)
                        Text("Manage AI infrastructure — providers, models, credentials, and agents")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Connection + local cache status
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AIStatusDot(active: apiReachable)
                        Text("API")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(state.providers.count > 0 ? "\(state.providers.count) providers · \(state.models.count) models · \(state.credentials.count) credentials" : "Loading…")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            Task { await state.syncCatalogFromNetwork() }
                        } label: {
                            Label(state.syncing ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .disabled(state.syncing)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: state.servingFromCache ? "internaldrive" : "checkmark.icloud")
                            .font(.system(size: 11))
                            .foregroundStyle(state.servingFromCache ? AIV2Style.accentAmber : AIV2Style.accentEmerald)
                        Text(cacheStatusText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)

                // Card grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    destinationCard("Providers", count: state.providers.count, icon: "server.rack", accent: AIV2Style.accentIndigo, target: .providers)
                    destinationCard("Models", count: state.models.count, icon: "cpu", accent: AIV2Style.accentBlue, target: .models)
                    destinationCard("Credentials", count: state.credentials.count, icon: "key.fill", accent: AIV2Style.accentEmerald, target: .credentials)
                    destinationCard("Inference", count: nil, icon: "sparkles", accent: AIV2Style.accentViolet, target: .inference)
                    destinationCard("Usage", count: state.usage.count, icon: "chart.bar", accent: AIV2Style.accentAmber, target: .usage)
                }
                .padding(.horizontal)

                // Sync history
                VStack(alignment: .leading, spacing: 8) {
                    Label("Latest synchronization", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let snapshot = state.snapshots.first {
                        VStack(spacing: 0) {
                            kvRow("Source", snapshot.source.rawValue)
                            Divider().padding(.leading, 80)
                            kvRow("Providers", snapshot.providerCount.formatted())
                            Divider().padding(.leading, 80)
                            kvRow("Models", snapshot.modelCount.formatted())
                            Divider().padding(.leading, 80)
                            kvRow("Changes", "\(snapshot.insertedCount) inserted · \(snapshot.updatedCount) updated")
                            Divider().padding(.leading, 80)
                            kvRow("Fetched", snapshot.fetchedAt)
                        }
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    } else if state.snapshotResource.isLoading {
                        AILoadingPlaceholder(count: 1, height: 120)
                    } else {
                        AIEmptyCard(message: "No catalog synchronizations")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .refreshable { await state.loadAll() }
    }

    private var apiReachable: Bool {
        [state.providerResource.error, state.modelResource.error, state.credentialResource.error, state.snapshotResource.error].allSatisfy { $0 == nil }
    }

    private var cacheStatusText: String {
        if state.servingFromCache {
            if let at = state.lastSyncedAt {
                return "Local DB · last sync \(at.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Local DB · showing cached catalog"
        }
        if let at = state.lastSyncedAt {
            return "Local DB in sync · \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return state.cache == nil ? "Local DB unavailable" : "Local DB ready"
    }

    private func kvRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func destinationCard(_ title: String, count: Int?, icon: String, accent: Color, target: AISection) -> some View {
        Button { section = target } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accent.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    if let count {
                        Text(count.formatted())
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Providers (q-hpc-panel card grid with inline form)
struct AIProvidersView: View {
    @EnvironmentObject private var state: AIState
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var showForm = false
    @State private var editing: AIProvider?
    @State private var deleting: AIProvider?
    @State private var discovering: AIProvider?
    @State private var testingSlug: String?
    @State private var testResult: String?
    @State private var showSyncModal = false
    @State private var syncSource: AICatalogSource = .api
    @State private var hoveredID: Int?

    private var filtered: [AIProvider] {
        state.providers.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.slug.localizedCaseInsensitiveContains(query) }
    }
    private var activeCount: Int { state.providers.filter(\.active).count }
    private var selfHostedCount: Int { state.providers.filter(\.isSelfHosted).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with actions
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(AIV2Style.accentIndigo)
                        .frame(width: 32, height: 32)
                        .background(AIV2Style.accentIndigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Providers v2")
                            .font(.title2).fontWeight(.bold)
                        Text("models.dev-aligned provider catalog")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showSyncModal = true } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(state.syncing)
                    Button { showForm = true; editing = nil } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Stats row
                AIStatsRow(values: [
                    ("Total", "\(state.providers.count)", nil),
                    ("Active", "\(activeCount)", AIV2Style.accentEmerald),
                    ("Self-hosted", "\(selfHostedCount)", AIV2Style.accentBlue),
                ])

                // Error banner
                if let error = state.providerResource.error {
                    AIErrorBanner(message: error) { Task { await state.reloadProviders() } }
                }

                // Sync result banner
                if let result = state.syncResult {
                    HStack(spacing: 6) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text("\(result.source.rawValue): \(result.providers) providers, \(result.models) models · \(result.inserted) inserted, \(result.updated) updated")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(result.success ? Color.green : Color.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((result.success ? Color.green : Color.orange).opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke((result.success ? Color.green : Color.orange).opacity(0.3), lineWidth: 1))
                    )
                    .padding(.horizontal)
                }

                // Search bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        TextField("Search providers…", text: $query)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.horizontal)
                }

                // Catalog history
                if !state.snapshots.isEmpty {
                    DisclosureGroup {
                        ForEach(state.snapshots) { snapshot in
                            HStack {
                                Text(snapshot.fetchedAt)
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                                Text("\(snapshot.source.rawValue) · \(snapshot.modelCount) models")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                        }
                    } label: {
                        Label("Catalog history (\(state.snapshots.count))", systemImage: "clock")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal)
                }

                // Inline form
                AIFormCard(isPresented: $showForm, title: editing != nil ? "Edit Provider" : "New Provider") {
                    AIProviderFormContent(
                        provider: editing,
                        onSave: { Task { await saveProvider() } },
                        onCancel: { showForm = false; editing = nil }
                    )
                }
                .id("form-\(editing?.id ?? -1)")

                // Provider cards
                if state.providerResource.isLoading && state.providers.isEmpty {
                    AILoadingPlaceholder(count: 4)
                } else if filtered.isEmpty {
                    AIEmptyCard(message: query.isEmpty ? "No providers yet. Use Sync to import the catalog." : "No providers match the search.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                        ForEach(filtered) { provider in
                            providerCard(provider)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .confirmationDialog("Delete provider?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { provider in
            Button("Delete \(provider.name)", role: .destructive) { Task { await state.deleteProvider(provider) } }
        } message: { _ in Text("This cannot be undone.") }
        .alert("Capability test", isPresented: Binding(get: { testResult != nil }, set: { if !$0 { testResult = nil } })) { Button("OK") {} } message: { Text(testResult ?? "") }
        // Sync modal
        .overlay(syncModal)
    }

    // MARK: - Provider Card
    private func providerCard(_ p: AIProvider) -> some View {
        let isHovered = hoveredID == p.id
        let modelCount = state.models.filter { $0.providerID == p.id }.count
        let accent: Color = p.active ? AIV2Style.accentIndigo : .gray

        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 12) {
                // Icon placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.3))
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                    )
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(p.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(p.slug)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    if p.isSelfHosted {
                        AIBadge(text: "Self-hosted", good: false)
                    }
                    AIStatusDot(active: p.active)
                }
            }

            if let desc = p.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Metadata row
            HStack(spacing: 12) {
                Label("\(modelCount) models", systemImage: "cpu")
                    .font(.system(size: 11))
                if p.credentialID != nil {
                    Label("Credential", systemImage: "key.fill")
                        .font(.system(size: 11))
                }
                if !p.env.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(p.env, id: \.self) { env in
                            Text(env)
                                .font(.system(size: 9, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .foregroundStyle(.secondary)

            if let baseURL = p.apiBaseURL, !baseURL.isEmpty {
                Label(baseURL, systemImage: "globe")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Discovery result
            if let result = state.discoverResults[p.slug] {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                    Text("Discovery: \(result.inserted) inserted, \(result.skipped) skipped, \(result.total) total")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.green)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.2), lineWidth: 1))
                )
            }

            // Action bar
            HStack(spacing: 0) {
                Group {
                    if let doc = p.doc, let url = URL(string: doc) {
                        Button("Docs") { openURL(url) }
                    }
                    if let site = p.website, let url = URL(string: site) {
                        Button("Site") { openURL(url) }
                    }
                    if isDiscoverable(p) {
                        Button("Discover") { discovering = p }
                    }
                    Button("Test") { Task { await test(p) } }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Spacer()

                Button { Task { await toggle(p) } } label: {
                    Text(p.active ? "Deactivate" : "Activate")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Button { editing = p; showForm = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Button { deleting = p } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.red)
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.gray.opacity(0.3)), alignment: .top)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovered ? accent.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(p.active ? 1 : 0.6)
        .onHover { hoveredID = $0 ? p.id : nil }
    }

    // MARK: - Sync Modal
    @ViewBuilder private var syncModal: some View {
        if showSyncModal {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { showSyncModal = false }
                .overlay(
                    AIModalCard {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync catalog from models.dev")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Fetches the public JSON catalog and upserts providers + models.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { showSyncModal = false } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)

                            VStack(spacing: 8) {
                                Picker("Source", selection: $syncSource) {
                                    ForEach(AICatalogSource.allCases, id: \.self) { source in
                                        Text(sourceDescripton(source)).tag(source)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if let result = state.syncResult {
                                    HStack(spacing: 4) {
                                        Text("Synced")
                                            .foregroundStyle(.secondary)
                                        Text("\(result.providers)").foregroundStyle(.primary)
                                        Text("providers ·")
                                            .foregroundStyle(.secondary)
                                        Text("\(result.models)").foregroundStyle(.primary)
                                        Text("models —")
                                            .foregroundStyle(.secondary)
                                        Text("\(result.inserted) inserted").foregroundStyle(Color.green)
                                        Text(",").foregroundStyle(.secondary)
                                        Text("\(result.updated) updated").foregroundStyle(AIV2Style.accentBlue)
                                    }
                                    .font(.system(size: 11))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.quaternary.opacity(0.3))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                            Divider()
                            HStack(spacing: 8) {
                                Spacer()
                                Button("Close") { showSyncModal = false }
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                Button {
                                    Task { await state.sync(source: syncSource) }
                                } label: {
                                    HStack(spacing: 4) {
                                        if state.syncing {
                                            ProgressView().scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 10))
                                        }
                                        Text("Sync")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(.white)
                                }
                                .disabled(state.syncing)
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                        }
                        .frame(width: 400)
                    }
                    , alignment: .center
                )
                .transition(.opacity)
                .zIndex(100)
        }
    }

    private func sourceDescripton(_ source: AICatalogSource) -> String {
        switch source {
        case .api: "api.json — providers + nested models"
        case .catalog: "catalog.json — combined"
        case .models: "models.json — provider-agnostic metadata"
        @unknown default: "unknown"
        }
    }

    // MARK: - Actions
    private func toggle(_ p: AIProvider) async {
        var update = AIProviderUpdate(); update.active = .value(!p.active)
        do { _ = try await state.api.updateProvider(slug: p.slug, update); await state.reloadProviders() } catch { state.error = String(describing: error) }
    }

    private func test(_ p: AIProvider) async {
        testingSlug = p.slug
        defer { testingSlug = nil }
        do {
            let value = try await state.api.providerCapabilities(slug: p.slug)
            let endpoints = value.endpoints?.joined(separator: ", ") ?? "No endpoint list"
            testResult = "\(p.name) is reachable. \(endpoints)"
        } catch { testResult = String(describing: error) }
    }

    private func saveProvider() async {
        // Handled by the form content
        showForm = false
        editing = nil
    }

    private func isDiscoverable(_ provider: AIProvider) -> Bool {
        ["ollama", "ollama-local", "ollama-cloud", "llamacpp-local", "llamacpp-cloud", "deepseek", "groq", "xai"].contains(provider.slug.lowercased())
    }
}

// MARK: - AI Models (q-hpc-panel style with provider chips, grouped table, info modal)
struct AIModelsView: View {
    @EnvironmentObject private var state: AIState
    @State private var query = ""
    @State private var selectedSlugs: Set<String> = []
    @State private var showDeprecated = false
    @State private var currentPage = 1
    @State private var showForm = false
    @State private var editing: AIModel?
    @State private var deleting: AIModel?
    @State private var selectedModel: AIModel?
    @State private var showInfoModel: AIModel?
    @State private var showProviders = false
    @State private var syncSource: AICatalogSource = .api
    private let perPage = 50

    private var filtered: [AIModel] {
        let q = query.trimmed.lowercased()
        var list = state.models
        if !showDeprecated { list = list.filter { $0.status != .deprecated } }
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.modelID.localizedCaseInsensitiveContains(q) ||
            ($0.modelFamily?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var paginated: [AIModel] {
        Array(filtered.dropFirst((currentPage - 1) * perPage).prefix(perPage))
    }

    private var totalPages: Int { max(1, Int(ceil(Double(filtered.count) / Double(perPage)))) }

    private struct ModelGroup: Identifiable {
        let key: String; let name: String; let slug: String?; var models: [AIModel]
        var id: String { key }
        init(key: String, name: String, slug: String?, models: [AIModel]) { self.key = key; self.name = name; self.slug = slug; self.models = models }
    }
    private var grouped: [ModelGroup] {
        var groups: [String: ModelGroup] = [:]
        for m in paginated {
            let key = m.providerSlug ?? m.providerName ?? String(m.providerID)
            if var g = groups[key] { g.models.append(m); groups[key] = g }
            else { groups[key] = ModelGroup(key: key, name: m.providerName ?? m.providerSlug ?? "—", slug: m.providerSlug, models: [m]) }
        }
        return groups.values.sorted { $0.name < $1.name }
    }

    private var credentialedSlugs: Set<String> {
        Set(state.credentials.filter { $0.status == "active" }.map(\.credentialType))
    }

    var body: some View {
        modelsBody
    }

    private var modelsBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                modelsHeader
                modelsStatsRow
                if let error = state.modelResource.error {
                    AIErrorBanner(message: error) { Task { await state.reloadModels() } }
                }
                providerChips
                modelsFilterBar
                modelsContent
            }
            .padding(.vertical)
        }
        .onChange(of: query) { _, _ in currentPage = 1 }
        .onChange(of: showDeprecated) { _, _ in currentPage = 1 }
        .onChange(of: selectedSlugs) { _, slugs in
            currentPage = 1
            if slugs.isEmpty { state.error = nil; return }
            Task { await state.reloadModels(providers: Array(slugs)) }
        }
        .sheet(isPresented: $showForm) { AIModelEditor(model: editing) }
        .confirmationDialog("Delete model?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { model in
            Button("Delete \(model.name)", role: .destructive) { Task { await state.deleteModel(model) } }
        }
        .overlay(infoModal)
    }

    @ViewBuilder
    private var modelsContent: some View {
        if !selectedSlugs.isEmpty && state.modelResource.isLoading && state.models.isEmpty {
            AILoadingPlaceholder(count: 6)
        } else if selectedSlugs.isEmpty && !state.modelResource.isLoading {
            AIEmptyCard(message: "Select providers above to view their models.")
        } else if filtered.isEmpty {
            AIEmptyCard(message: "No models match.")
        } else {
            groupedModelsView
            if totalPages > 1 {
                modelsPagination
            }
        }
    }

    private var modelsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(AIV2Style.accentBlue)
                .frame(width: 32, height: 32)
                .background(AIV2Style.accentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Models v2")
                    .font(.title2).fontWeight(.bold)
                Text("models.dev catalog — capabilities, modalities & per-1M pricing")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await state.sync(source: syncSource) } } label: {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(state.syncing)
            Button { showForm = true; editing = nil } label: {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private var modelsStatsRow: some View {
        let values: [(String, String, Color?)] = [
            ("Total", "\(state.models.count)", nil),
            ("Visible", "\(filtered.count)", nil),
            ("Reasoning", "\(state.models.filter(\.reasoning).count)", AIV2Style.accentViolet),
            ("Tool-calling", "\(state.models.filter(\.toolCall).count)", AIV2Style.accentAmber),
        ]
        return AIStatsRow(values: values)
    }

    private var modelsPagination: some View {
        HStack(spacing: 8) {
            Button("First") { currentPage = 1 }.disabled(currentPage <= 1)
            Button("Prev") { currentPage = max(1, currentPage - 1) }.disabled(currentPage <= 1)
            Text("Page \(currentPage) of \(totalPages)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Button("Next") { currentPage = min(totalPages, currentPage + 1) }.disabled(currentPage >= totalPages)
            Button("Last") { currentPage = totalPages }.disabled(currentPage >= totalPages)
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
    }

    private var modelsFilterBar: some View {
        let searchBar = HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.tertiary)
            TextField("Search models…", text: $query).font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))

        let deprecatedToggle = Toggle("Deprecated", isOn: $showDeprecated)
            .toggleStyle(.button)
            .font(.system(size: 12, weight: .medium))
            .controlSize(.small)

        return HStack(spacing: 8) {
            searchBar
            deprecatedToggle
            if totalPages > 1 {
                paginationControls(currentPage: $currentPage, totalPages: totalPages)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Grouped Models View
    private var groupedModelsView: some View {
        VStack(spacing: 0) {
            ForEach(grouped) { group in
                providerGroupSection(group)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Provider Chips
    private var providerChips: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.2)) { showProviders.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .rotationEffect(.degrees(showProviders ? 0 : -90))
                    Text("Providers")
                        .font(.system(size: 11, weight: .medium))
                        .textCase(.uppercase)
                    if !selectedSlugs.isEmpty {
                        Text("\(selectedSlugs.count) selected")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AIV2Style.accentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(AIV2Style.accentBlue)
                    }
                    Spacer()
                    Button("Select all") {
                        selectedSlugs = Set(state.providers.map(\.slug))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    Button("Clear") {
                        selectedSlugs = []
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showProviders {
                VStack(spacing: 6) {
                    let credited = state.providers.filter { credentialedSlugs.contains($0.slug) }
                    let uncredited = state.providers.filter { !credentialedSlugs.contains($0.slug) }
                    if !credited.isEmpty {
                        AISectionHeader(title: "With credentials")
                        chipRow(credited)
                    }
                    if !uncredited.isEmpty {
                        AISectionHeader(title: "Without credentials")
                        chipRow(uncredited)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func chipRow(_ providers: [AIProvider]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 6) {
            ForEach(providers) { p in
                AIChipToggle(
                    label: p.name,
                    icon: credentialedSlugs.contains(p.slug) ? "key.fill" : nil,
                    isSelected: selectedSlugs.contains(p.slug),
                    accent: AIV2Style.accentBlue
                ) {
                    if selectedSlugs.contains(p.slug) {
                        selectedSlugs.remove(p.slug)
                    } else {
                        selectedSlugs.insert(p.slug)
                    }
                }
            }
        }
    }

    // MARK: - Provider Group Section
    private func providerGroupSection(_ g: ModelGroup) -> some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(0))
                Text(g.name)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(g.models.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
            .background(.quaternary.opacity(0.15))

            Divider()

            // Model rows
            ForEach(g.models) { model in
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        // Model info
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                if model.isDefault {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AIV2Style.accentAmber)
                                }
                                Text(model.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                if let status = model.status {
                                    AIBadge(text: status.rawValue, good: status != .deprecated)
                                }
                            }
                            Text(model.modelID)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()

                        // Capability icons
                        HStack(spacing: 6) {
                            if model.reasoning { Image(systemName: "brain").foregroundStyle(AIV2Style.accentViolet) }
                            if model.toolCall { Image(systemName: "wrench.and.screwdriver").foregroundStyle(AIV2Style.accentAmber) }
                            if model.attachment { Image(systemName: "paperclip").foregroundStyle(AIV2Style.accentSky) }
                            if model.modalitiesInput.contains(.image) { Image(systemName: "eye").foregroundStyle(AIV2Style.accentEmerald) }
                        }
                        .font(.system(size: 10))

                        // Context
                        Text(fmtCtx(model.limitContext))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)

                        // Pricing
                        Text("\(fmtPrice(model.costInput)) / \(fmtPrice(model.costOutput))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 80, alignment: .trailing)
                            .lineLimit(1)

                        // Actions
                        HStack(spacing: 4) {
                            Button { showInfoModel = model } label: {
                                Image(systemName: "info.circle").font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            Button { editing = model; showForm = true } label: {
                                Image(systemName: "pencil").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            Button { deleting = model } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    // MARK: - Info Modal
    @ViewBuilder private var infoModal: some View {
        if let model = showInfoModel {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { showInfoModel = nil }
                .overlay(
                    AIModalCard {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Header
                                HStack(spacing: 10) {
                                    if model.isDefault {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AIV2Style.accentAmber)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(model.name)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(model.modelID)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let status = model.status {
                                        AIBadge(text: status.rawValue, good: status != .deprecated)
                                    }
                                    Button { showInfoModel = nil } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(16)

                                Divider()

                                // Sections
                                infoSection("Identity")
                                AIKVRow(label: "ID", value: "\(model.id)")
                                AIKVRow(label: "Model ID", value: model.modelID, mono: true)
                                AIKVRow(label: "Name", value: model.name)
                                AIKVRow(label: "Family", value: model.modelFamily ?? "—", mono: true)
                                AIKVRow(label: "Provider", value: model.providerName ?? model.providerSlug ?? "—")
                                AIKVRow(label: "Currency", value: model.currency)
                                AIKVBoolRow(label: "Default", value: model.isDefault)

                                infoSection("Capabilities")
                                AIKVBoolRow(label: "Attachment", value: model.attachment)
                                AIKVBoolRow(label: "Reasoning", value: model.reasoning)
                                AIKVBoolRow(label: "Tool call", value: model.toolCall)
                                AIKVBoolRow(label: "Structured output", value: model.structuredOutput)
                                AIKVBoolRow(label: "Open weights", value: model.openWeights)

                                infoSection("Lifecycle")
                                AIKVRow(label: "Status", value: model.status?.rawValue ?? "stable")
                                AIKVRow(label: "Release date", value: model.releaseDate.isEmpty ? "—" : model.releaseDate, mono: true)
                                AIKVRow(label: "Knowledge cutoff", value: model.knowledge ?? "—")

                                infoSection("Limits")
                                AIKVRow(label: "Context", value: model.limitContext.formatted(), mono: true)
                                AIKVRow(label: "Input limit", value: model.limitInput?.formatted() ?? "—", mono: true)
                                AIKVRow(label: "Output limit", value: model.limitOutput.formatted(), mono: true)

                                infoSection("Modalities")
                                AIKVChipsRow(label: "Input", values: model.modalitiesInput.map(\.rawValue))
                                AIKVChipsRow(label: "Output", values: model.modalitiesOutput.map(\.rawValue))

                                infoSection("Pricing (per 1M tokens)")
                                AIKVRow(label: "Input", value: fmtPrice(model.costInput), mono: true)
                                AIKVRow(label: "Output", value: fmtPrice(model.costOutput), mono: true)
                                AIKVRow(label: "Reasoning", value: fmtPrice(model.costReasoning), mono: true)
                                AIKVRow(label: "Cache read", value: fmtPrice(model.costCacheRead), mono: true)
                                AIKVRow(label: "Cache write", value: fmtPrice(model.costCacheWrite), mono: true)
                                AIKVRow(label: "Audio input", value: fmtPrice(model.costInputAudio), mono: true)
                                AIKVRow(label: "Audio output", value: fmtPrice(model.costOutputAudio), mono: true)

                                infoSection("Metadata")
                                AIKVRow(label: "License", value: model.license ?? "—")
                                AIKVRow(label: "Base model", value: model.baseModel ?? "—", mono: true)
                            }
                        }
                        .frame(maxHeight: 500)

                        Divider()
                        HStack(spacing: 8) {
                            Spacer()
                            Button("Edit") { showInfoModel = nil; editing = model; showForm = true }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
                            Button("Close") { showInfoModel = nil }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                    .frame(width: 420)
                    , alignment: .center
                )
                .transition(.opacity)
                .zIndex(100)
        }
    }

    private func infoSection(_ title: String) -> some View {
        AISectionHeader(title: title)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.15))
    }

    private func fmtPrice(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "$\(String(format: "%.2f", v))"
    }

    private func fmtCtx(_ v: Int) -> String {
        if v >= 1_000 { return "\(v / 1_000)k" }
        return "\(v)"
    }

    @ViewBuilder
    private func paginationControls(currentPage: Binding<Int>, totalPages: Int) -> some View {
        HStack(spacing: 4) {
            Button { currentPage.wrappedValue = max(1, currentPage.wrappedValue - 1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 10))
            }
            .disabled(currentPage.wrappedValue <= 1)
            .buttonStyle(.plain)
            .foregroundStyle(currentPage.wrappedValue <= 1 ? .tertiary : .primary)

            Text("\(currentPage.wrappedValue)/\(totalPages)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Button { currentPage.wrappedValue = min(totalPages, currentPage.wrappedValue + 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 10))
            }
            .disabled(currentPage.wrappedValue >= totalPages)
            .buttonStyle(.plain)
            .foregroundStyle(currentPage.wrappedValue >= totalPages ? .tertiary : .primary)
        }
    }
}

// MARK: - AI Provider Form (inline, q-hpc-panel style)
private struct AIProviderFormContent: View {
    @EnvironmentObject private var state: AIState
    let provider: AIProvider?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var slug = ""
    @State private var name = ""
    @State private var npm = ""
    @State private var doc = ""
    @State private var website = ""
    @State private var apiBaseURL = ""
    @State private var description = ""
    @State private var env = ""
    @State private var isSelfHosted = false
    @State private var credentialID = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            // Row 1
            HStack(spacing: 12) {
                field("Slug", text: $slug, placeholder: "openai", disabled: provider != nil)
                field("Name", text: $name, placeholder: "OpenAI")
            }
            HStack(spacing: 12) {
                field("NPM module", text: $npm, placeholder: "@ai-sdk/openai", mono: true)
                field("Docs URL", text: $doc, placeholder: "https://...")
            }
            HStack(spacing: 12) {
                field("Website", text: $website, placeholder: "https://openai.com")
                field("API Base URL", text: $apiBaseURL, placeholder: "https://api.openai.com/v1", mono: true)
            }
            field("Env vars (comma-separated)", text: $env, placeholder: "OPENAI_API_KEY", mono: true)
            field("Description", text: $description, placeholder: "Creator of GPT models...")

            // Credential picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Default credential")
                    .font(.system(size: 12, weight: .medium))
                Picker("", selection: $credentialID) {
                    Text("No default credential").tag("")
                    ForEach(state.credentials) { c in
                        Text("\(c.name) · \(c.environment) · \(c.credentialType)").tag(String(c.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }

            HStack {
                Toggle("Self-Hosted", isOn: $isSelfHosted)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                Spacer()
                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
                    Button("Save") { Task { await save() } }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                        .disabled(slug.trimmed.isEmpty || name.trimmed.isEmpty || npm.trimmed.isEmpty || saving)
                }
                .buttonStyle(.plain)
            }
            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .onAppear { load() }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, mono: Bool = false, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            TextField(placeholder, text: text)
                .font(.system(size: 13, design: mono ? .monospaced : .default))
                .disabled(disabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }

    private func load() {
        guard let p = provider else { return }
        slug = p.slug; name = p.name; npm = p.npm ?? ""
        doc = p.doc ?? ""; website = p.website ?? ""
        apiBaseURL = p.apiBaseURL ?? ""; description = p.description ?? ""
        env = p.env.joined(separator: ", ")
        isSelfHosted = p.isSelfHosted; credentialID = p.credentialID.map(String.init) ?? ""
    }

    private func save() async {
        saving = true; defer { saving = false }
        do {
            let selectedCredID = Int(credentialID)
            if let p = provider {
                var patch = AIProviderUpdate()
                patch.name = .value(name.trimmed); patch.slug = .value(slug.trimmed); patch.npm = .value(npm.trimmed)
                patch.doc = patchText(doc); patch.website = patchText(website); patch.description = patchText(description)
                patch.apiBaseURL = patchText(apiBaseURL); patch.env = .value(env.csv)
                patch.isSelfHosted = .value(isSelfHosted)
                patch.credentialID = selectedCredID.map(AIPatch.value) ?? .null
                _ = try await state.api.updateProvider(slug: p.slug, patch)
            } else {
                var create = AIProviderCreate(slug: slug.trimmed, name: name.trimmed, npm: npm.trimmed, env: env.csv)
                create.doc = doc.optional; create.website = website.optional; create.description = description.optional
                create.apiBaseURL = apiBaseURL.optional; create.isSelfHosted = isSelfHosted; create.credentialID = selectedCredID
                _ = try await state.api.createProvider(create)
            }
            await state.reloadProviders(); onSave()
        } catch { self.error = String(describing: error) }
    }
}

// MARK: - Model Editor (sheet, preserved from original)
private struct AIModelEditor: View {
    @EnvironmentObject private var state: AIState
    @Environment(\.dismiss) private var dismiss
    let model: AIModel?
    @State private var providerID: Int?; @State private var modelID = ""; @State private var name = ""; @State private var family = ""
    @State private var status = ""; @State private var releaseDate = ""; @State private var lastUpdated = ""; @State private var knowledge = ""
    @State private var context = 0; @State private var inputLimit = ""; @State private var output = 0
    @State private var inputModalities: Set<AIModality> = [.text]; @State private var outputModalities: Set<AIModality> = [.text]
    @State private var attachment = false; @State private var reasoning = false; @State private var tools = false; @State private var structured = false; @State private var supportsTemperature = true; @State private var openWeights = false; @State private var isDefault = false
    @State private var currency = "USD"; @State private var costs = [String: String](); @State private var license = ""; @State private var baseModel = ""; @State private var baseModelOmit = ""
    @State private var advanced = [String: String](); @State private var openRouterModeration = "unset"; @State private var validation: String?; @State private var saving = false

    private let jsonFields = ["reasoning_options", "interleaved", "links", "weights", "benchmarks", "cost_context_over_200k", "cost_tiers", "experimental", "provider_overrides", "openrouter_metadata", "openrouter_supported_parameters", "openrouter_pricing", "openrouter_architecture", "openrouter_top_provider"]
    private let costFields = ["input", "output", "reasoning", "cache_read", "cache_write", "input_audio", "output_audio"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") { Picker("Provider", selection: $providerID) { Text("Select").tag(Int?.none); ForEach(state.providers) { Text($0.name).tag(Optional($0.id)) } }.disabled(model != nil); TextField("Model ID", text: $modelID).disabled(model != nil); TextField("Name", text: $name); TextField("Family", text: $family) }
                Section("Lifecycle") { Picker("Status", selection: $status) { Text("Stable").tag(""); ForEach(AIModelStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) } }; TextField("Release date", text: $releaseDate); TextField("Last updated", text: $lastUpdated); TextField("Knowledge cutoff", text: $knowledge) }
                Section("Limits") { TextField("Context", value: $context, format: .number); TextField("Input (blank = null)", text: $inputLimit); TextField("Output", value: $output, format: .number) }
                Section("Modalities") { modalityGrid("Input", selection: $inputModalities); modalityGrid("Output", selection: $outputModalities) }
                Section("Capabilities") { Toggle("Attachments", isOn: $attachment); Toggle("Reasoning", isOn: $reasoning); Toggle("Tool calls", isOn: $tools); Toggle("Structured output", isOn: $structured); Toggle("Temperature", isOn: $supportsTemperature); Toggle("Open weights", isOn: $openWeights); Toggle("Default", isOn: $isDefault) }
                Section("Pricing per 1M") { TextField("Currency", text: $currency); ForEach(costFields, id: \.self) { field in TextField(field.replacingOccurrences(of: "_", with: " ").capitalized, text: binding(costs, field)) } }
                Section("Metadata") { TextField("License", text: $license); TextField("Base model", text: $baseModel); TextField("Base model omissions (comma separated)", text: $baseModelOmit) }
                Section("Advanced JSON") {
                    Picker("OpenRouter moderated", selection: $openRouterModeration) { Text("Unset").tag("unset"); Text("Yes").tag("true"); Text("No").tag("false") }
                    ForEach(jsonFields, id: \.self) { field in TextField(field.replacingOccurrences(of: "_", with: " ").capitalized, text: binding(advanced, field), axis: .vertical).font(.caption.monospaced()) }
                }
                if let validation { Section { Text(validation).foregroundStyle(.red) } }
            }
            .navigationTitle(model == nil ? "Add Model" : "Edit Model")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(providerID == nil || modelID.trimmed.isEmpty || name.trimmed.isEmpty || saving) } }
        }.onAppear { load() }
    }

    @ViewBuilder private func modalityGrid(_ title: String, selection: Binding<Set<AIModality>>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); HStack { ForEach(AIModality.allCases, id: \.self) { item in Toggle(item.rawValue, isOn: Binding(get: { selection.wrappedValue.contains(item) }, set: { if $0 { selection.wrappedValue.insert(item) } else { selection.wrappedValue.remove(item) } })).toggleStyle(.button) } } }
    }

    private func binding(_ dictionary: [String: String], _ key: String) -> Binding<String> { Binding(get: { dictionary[key] ?? "" }, set: { if costs.keys.contains(key) || costFields.contains(key) { costs[key] = $0 } else { advanced[key] = $0 } }) }

    private func load() {
        guard let m = model else { return }
        providerID = m.providerID; modelID = m.modelID; name = m.name; family = m.modelFamily ?? ""; status = m.status?.rawValue ?? ""; releaseDate = m.releaseDate; lastUpdated = m.lastUpdated; knowledge = m.knowledge ?? ""
        context = m.limitContext; inputLimit = m.limitInput?.description ?? ""; output = m.limitOutput; inputModalities = Set(m.modalitiesInput); outputModalities = Set(m.modalitiesOutput)
        attachment = m.attachment; reasoning = m.reasoning; tools = m.toolCall; structured = m.structuredOutput ?? false; supportsTemperature = m.temperature ?? true; openWeights = m.openWeights; isDefault = m.isDefault; currency = m.currency
        costs = ["input": number(m.costInput), "output": number(m.costOutput), "reasoning": number(m.costReasoning), "cache_read": number(m.costCacheRead), "cache_write": number(m.costCacheWrite), "input_audio": number(m.costInputAudio), "output_audio": number(m.costOutputAudio)]
        license = m.license ?? ""; baseModel = m.baseModel ?? ""; baseModelOmit = m.baseModelOmit?.joined(separator: ", ") ?? ""
        advanced = ["reasoning_options": prettyEncodable(m.reasoningOptions), "interleaved": prettyEncodable(m.interleaved), "links": prettyEncodable(m.links), "weights": prettyEncodable(m.weights), "benchmarks": prettyEncodable(m.benchmarks), "cost_context_over_200k": pretty(m.costContextOver200K), "cost_tiers": prettyEncodable(m.costTiers), "experimental": pretty(m.experimental), "provider_overrides": pretty(m.providerOverrides), "openrouter_metadata": pretty(m.openrouterMetadata), "openrouter_supported_parameters": pretty(m.openrouterSupportedParameters), "openrouter_pricing": pretty(m.openrouterPricing), "openrouter_architecture": pretty(m.openrouterArchitecture), "openrouter_top_provider": pretty(m.openrouterTopProvider)]
        openRouterModeration = m.openrouterIsModerated.map { $0 ? "true" : "false" } ?? "unset"
    }

    private func save() async {
        saving = true; defer { saving = false }
        do {
            guard context >= 0, output >= 0, (Int(inputLimit) ?? 0) >= 0 else { throw AIFormError("Limits cannot be negative.") }
            for field in costFields { if let value = Double(costs[field] ?? ""), value < 0 { throw AIFormError("\(field) price cannot be negative.") } }
            let json = try validatedAdvanced()
            if let model {
                var p = AIModelUpdate(); p.name = .value(name.trimmed); p.modelFamily = patchText(family); p.status = status.isEmpty ? .null : .value(AIModelStatus(rawValue: status)!)
                p.releaseDate = patchText(releaseDate); p.lastUpdated = patchText(lastUpdated); p.knowledge = patchText(knowledge); p.limitContext = .value(context); p.limitInput = inputLimit.trimmed.isEmpty ? .null : .value(Int(inputLimit)!); p.limitOutput = .value(output)
                p.modalitiesInput = .value(Array(inputModalities).sorted { $0.rawValue < $1.rawValue }); p.modalitiesOutput = .value(Array(outputModalities).sorted { $0.rawValue < $1.rawValue }); p.currency = .value(currency)
                p.attachment = .value(attachment); p.reasoning = .value(reasoning); p.toolCall = .value(tools); p.structuredOutput = .value(structured); p.temperature = .value(supportsTemperature); p.openWeights = .value(openWeights); p.isDefault = .value(isDefault)
                applyCosts(&p); p.license = patchText(license); p.baseModel = patchText(baseModel); p.baseModelOmit = baseModelOmit.trimmed.isEmpty ? .null : .value(baseModelOmit.csv); try applyAdvanced(json, to: &p)
                p.openrouterIsModerated = openRouterModeration == "unset" ? .null : .value(openRouterModeration == "true")
                _ = try await state.api.updateModel(id: model.id, p)
            } else {
                guard let providerID else { return }
                var c = AIModelCreate(providerID: providerID, modelID: modelID.trimmed, name: name.trimmed); c.modelFamily = family.optional; c.status = AIModelStatus(rawValue: status); c.releaseDate = releaseDate.optional; c.lastUpdated = lastUpdated.optional; c.knowledge = knowledge.optional
                c.limitContext = context; c.limitInput = Int(inputLimit); c.limitOutput = output; c.modalitiesInput = Array(inputModalities); c.modalitiesOutput = Array(outputModalities); c.currency = currency
                c.attachment = attachment; c.reasoning = reasoning; c.toolCall = tools; c.structuredOutput = structured; c.temperature = supportsTemperature; c.openWeights = openWeights; c.isDefault = isDefault
                applyCosts(&c); c.license = license.optional; c.baseModel = baseModel.optional; c.baseModelOmit = baseModelOmit.trimmed.isEmpty ? nil : baseModelOmit.csv; try applyAdvanced(json, to: &c)
                c.openrouterIsModerated = openRouterModeration == "unset" ? nil : openRouterModeration == "true"
                _ = try await state.api.createModel(c)
            }
            await state.reloadModels(); dismiss()
        } catch { validation = String(describing: error) }
    }

    private func validatedAdvanced() throws -> [String: Data] {
        var result: [String: Data] = [:]
        for field in jsonFields where !(advanced[field] ?? "").trimmed.isEmpty {
            let data = Data((advanced[field] ?? "").utf8)
            guard (try? JSONSerialization.jsonObject(with: data)) != nil else { throw AIFormError("\(field.replacingOccurrences(of: "_", with: " ").capitalized) contains invalid JSON.") }
            result[field] = data
        }
        return result
    }

    private func applyCosts(_ model: inout AIModelCreate) { model.costInput = Double(costs["input"] ?? ""); model.costOutput = Double(costs["output"] ?? ""); model.costReasoning = Double(costs["reasoning"] ?? ""); model.costCacheRead = Double(costs["cache_read"] ?? ""); model.costCacheWrite = Double(costs["cache_write"] ?? ""); model.costInputAudio = Double(costs["input_audio"] ?? ""); model.costOutputAudio = Double(costs["output_audio"] ?? "") }
    private func applyCosts(_ model: inout AIModelUpdate) { model.costInput = patchDouble(costs["input"]); model.costOutput = patchDouble(costs["output"]); model.costReasoning = patchDouble(costs["reasoning"]); model.costCacheRead = patchDouble(costs["cache_read"]); model.costCacheWrite = patchDouble(costs["cache_write"]); model.costInputAudio = patchDouble(costs["input_audio"]); model.costOutputAudio = patchDouble(costs["output_audio"]) }
    private func applyAdvanced(_ json: [String: Data], to model: inout AIModelCreate) throws {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        model.reasoningOptions = try json["reasoning_options"].map { try d.decode([AIReasoningOption].self, from: $0) }; model.interleaved = try json["interleaved"].map { try d.decode(AIInterleaved.self, from: $0) }; model.links = try json["links"].map { try d.decode([AIModelLink].self, from: $0) }; model.weights = try json["weights"].map { try d.decode([AIModelWeights].self, from: $0) }; model.benchmarks = try json["benchmarks"].map { try d.decode([AIBenchmarkResult].self, from: $0) }
        model.costContextOver200K = try object(json["cost_context_over_200k"]); model.costTiers = try objects(json["cost_tiers"]); model.experimental = try object(json["experimental"]); model.providerOverrides = try object(json["provider_overrides"]); model.openrouterMetadata = try object(json["openrouter_metadata"]); model.openrouterSupportedParameters = try object(json["openrouter_supported_parameters"]); model.openrouterPricing = try object(json["openrouter_pricing"]); model.openrouterArchitecture = try object(json["openrouter_architecture"]); model.openrouterTopProvider = try object(json["openrouter_top_provider"])
    }
    private func applyAdvanced(_ json: [String: Data], to model: inout AIModelUpdate) throws {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        model.reasoningOptions = try patch(json["reasoning_options"], as: [AIReasoningOption].self, decoder: d); model.interleaved = try patch(json["interleaved"], as: AIInterleaved.self, decoder: d); model.links = try patch(json["links"], as: [AIModelLink].self, decoder: d); model.weights = try patch(json["weights"], as: [AIModelWeights].self, decoder: d); model.benchmarks = try patch(json["benchmarks"], as: [AIBenchmarkResult].self, decoder: d)
        model.costContextOver200K = patchObject(json["cost_context_over_200k"]); model.costTiers = patchObjects(json["cost_tiers"]); model.experimental = patchObject(json["experimental"]); model.providerOverrides = patchObject(json["provider_overrides"]); model.openrouterMetadata = patchObject(json["openrouter_metadata"]); model.openrouterSupportedParameters = patchObject(json["openrouter_supported_parameters"]); model.openrouterPricing = patchObject(json["openrouter_pricing"]); model.openrouterArchitecture = patchObject(json["openrouter_architecture"]); model.openrouterTopProvider = patchObject(json["openrouter_top_provider"])
    }
}

// MARK: - Helpers
private struct AIFormError: LocalizedError { let text: String; init(_ text: String) { self.text = text }; var errorDescription: String? { text } }
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var optional: String? { trimmed.isEmpty ? nil : trimmed }
    var csv: [String] { split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty } }
}
private func patchText(_ value: String) -> AIPatch<String> { value.trimmed.isEmpty ? .null : .value(value.trimmed) }
private func patchDouble(_ value: String?) -> AIPatch<Double> { value?.trimmed.isEmpty != false ? .null : .value(Double(value!)!) }
private func number(_ value: Double?) -> String { value.map { String($0) } ?? "" }
private func pretty(_ object: [String: AIJSONValue]?) -> String { object.map(prettyEncodable) ?? "" }
private func prettyEncodable<T: Encodable>(_ value: T?) -> String { guard let value, let data = try? JSONEncoder().encode(value), let object = try? JSONSerialization.jsonObject(with: data), let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return "" }; return String(decoding: pretty, as: UTF8.self) }
private func object(_ data: Data?) throws -> [String: AIJSONValue]? { try data.map { try JSONDecoder().decode([String: AIJSONValue].self, from: $0) } }
private func objects(_ data: Data?) throws -> [[String: AIJSONValue]]? { try data.map { try JSONDecoder().decode([[String: AIJSONValue]].self, from: $0) } }
private func patchObject(_ data: Data?) -> AIPatch<[String: AIJSONValue]> { data.flatMap { try? JSONDecoder().decode([String: AIJSONValue].self, from: $0) }.map(AIPatch.value) ?? .null }
private func patchObjects(_ data: Data?) -> AIPatch<[[String: AIJSONValue]]> { data.flatMap { try? JSONDecoder().decode([[String: AIJSONValue]].self, from: $0) }.map(AIPatch.value) ?? .null }
private func patch<T: Decodable & Encodable & Sendable>(_ data: Data?, as: T.Type, decoder: JSONDecoder) throws -> AIPatch<T> { guard let data else { return .null }; return .value(try decoder.decode(T.self, from: data)) }
