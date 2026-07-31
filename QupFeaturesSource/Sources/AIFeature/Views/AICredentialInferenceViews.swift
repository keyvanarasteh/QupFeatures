import AIAPI
import FoundationModelsKit
import SwiftUI

// MARK: - AICredentialsView (q-hpc-panel card grid + inline form with tabs)
struct AICredentialsView: View {
    @EnvironmentObject private var state: AIState
    @State private var query = ""
    @State private var showForm = false
    @State private var editing: AICredential?
    @State private var deleting: AICredential?
    @State private var revealingID: Int?
    @State private var revealedID: Int?
    @State private var revealedKey: String?
    @State private var copiedKey = false
    @State private var testingID: Int?
    @State private var testResults: [Int: AICredentialTest] = [:]
    @State private var creditsModal: (name: String, result: AICredentialCreditsResult)?
    @State private var checkingCreditsID: Int?
    @State private var hoveredID: Int?

    private var filtered: [AICredential] {
        state.credentials.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.credentialType.localizedCaseInsensitiveContains(query) || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    private var activeCount: Int { state.credentials.filter { $0.status == "active" }.count }
    private var sharedCount: Int { state.credentials.filter(\.isShared).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundStyle(AIV2Style.accentEmerald)
                        .frame(width: 32, height: 32)
                        .background(AIV2Style.accentEmerald.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Credentials v2")
                            .font(.title2).fontWeight(.bold)
                        Text("API keys for the models.dev-aligned catalog")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
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

                // Stats
                AIStatsRow(values: [
                    ("Total", "\(state.credentials.count)", nil),
                    ("Active", "\(activeCount)", AIV2Style.accentEmerald),
                    ("Shared", "\(sharedCount)", AIV2Style.accentBlue),
                ])

                // Error
                if let error = state.credentialResource.error {
                    AIErrorBanner(message: error) { Task { await state.reloadCredentials() } }
                }

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.tertiary)
                    TextField("Search credentials…", text: $query)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

                // Inline Form
                AIFormCard(isPresented: $showForm, title: editing != nil ? "Edit Credential" : "New Credential") {
                    AICredentialFormContent(
                        credential: editing,
                        onSave: { Task { await saveForm() } },
                        onCancel: { showForm = false; editing = nil }
                    )
                }
                .id("form-\(editing?.id ?? -1)")

                // Credential cards
                if state.credentialResource.isLoading && state.credentials.isEmpty {
                    AILoadingPlaceholder(count: 3)
                } else if filtered.isEmpty {
                    AIEmptyCard(message: query.isEmpty ? "No credentials yet." : "No credentials match the search.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                        ForEach(filtered) { credential in
                            credentialCard(credential)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .confirmationDialog("Delete credential?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { credential in
            Button("Delete \(credential.name)", role: .destructive) { Task { await state.deleteCredential(credential) } }
        } message: { _ in Text("The secret and its shares will no longer be available.") }
        // Credits modal
        .overlay(creditsOverlay)
    }

    // MARK: - Credential Card
    private func credentialCard(_ c: AICredential) -> some View {
        let isHovered = hoveredID == c.id
        let testResult = testResults[c.id]
        let isRevealed = revealedID == c.id
        let isActive = c.status == "active"

        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AIV2Style.accentEmerald.opacity(0.1))
                    .overlay(Image(systemName: "key.fill").font(.system(size: 14)).foregroundStyle(AIV2Style.accentEmerald))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(c.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("\(c.credentialType) · \(c.environment)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    if c.isShared {
                        AIBadge(text: "Shared", good: true)
                    }
                    AIBadge(text: c.status, good: isActive)
                }
            }

            if let desc = c.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let lastUsed = c.lastUsedAt {
                Text("Last used: \(formatDate(lastUsed))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            if let expires = c.expiresAt {
                Text("Expires: \(expires.prefix(10))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Test result banner
            if let tr = testResult {
                let good = tr.valid == true
                HStack(spacing: 4) {
                    Image(systemName: good ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 9))
                    Text(good ? "Valid" : (tr.reachable ? "Invalid" : "Unreachable"))
                    if !good, let error = tr.error { Text("· \(error)").lineLimit(1) }
                    Text("· \(String(format: "%.0f", tr.latencyMs))ms")
                }
                .font(.system(size: 10))
                .foregroundStyle(good ? Color.green : .red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill((good ? Color.green : Color.red).opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke((good ? Color.green : Color.red).opacity(0.2), lineWidth: 1))
                )
            }

            // Revealed key
            if isRevealed, let key = revealedKey {
                HStack(spacing: 6) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AIV2Style.accentEmerald)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        copyToPasteboard(key)
                        copiedKey = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedKey = false }
                    } label: {
                        Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copiedKey ? Color.green : .secondary)
                    Button { revealedID = nil; revealedKey = nil; copiedKey = false } label: {
                        Image(systemName: "xmark").font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AIV2Style.accentEmerald.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AIV2Style.accentEmerald.opacity(0.2), lineWidth: 1))
                )
            }

            // Actions bar
            HStack(spacing: 0) {
                Group {
                    if supportsCredits(c) {
                        Button("Credits") { Task { await checkCredits(c) } }
                            .disabled(checkingCreditsID == c.id)
                    }
                    Button("Test") { Task { await runTest(c) } }
                        .disabled(testingID == c.id)
                    Button("Reveal") { Task { await revealKey(c) } }
                        .disabled(revealingID == c.id)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Spacer()

                Button("Edit") { editing = c; showForm = true }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                Button { deleting = c } label: {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .foregroundStyle(.red)
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.gray.opacity(0.2)), alignment: .top)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovered ? AIV2Style.accentEmerald.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .onHover { hoveredID = $0 ? c.id : nil }
    }

    // MARK: - Credits Modal
    @ViewBuilder private var creditsOverlay: some View {
        if let cm = creditsModal {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { creditsModal = nil }
                .overlay(
                    AIModalCard {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "coins")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AIV2Style.accentAmber)
                                Text("Credits — \(cm.name)")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Button { creditsModal = nil } label: {
                                    Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)

                            Divider()

                            VStack(spacing: 12) {
                                if case .openRouter(let total, let used, let remaining) = cm.result {
                                    statGrid([
                                        ("Total", "$\(String(format: "%.4f", total))", nil),
                                        ("Used", "$\(String(format: "%.4f", used))", AIV2Style.accentAmber),
                                        ("Remaining", "$\(String(format: "%.4f", remaining))", AIV2Style.accentEmerald),
                                    ])
                                } else if case .deepSeek(let available, let balances) = cm.result {
                                    HStack(spacing: 6) {
                                        AIStatusDot(active: available)
                                        Text("Service \(available ? "available" : "unavailable")")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 4)
                                    ForEach(Array(balances.enumerated()), id: \.offset) { _, b in
                                        VStack(spacing: 4) {
                                            Text(b.currency).font(.system(size: 11, weight: .semibold)).textCase(.uppercase)
                                            statGrid([
                                                ("Total", b.totalBalance, nil),
                                                ("Granted", b.grantedBalance, AIV2Style.accentBlue),
                                                ("Topped Up", b.toppedUpBalance, AIV2Style.accentEmerald),
                                            ])
                                        }
                                    }
                                }
                            }
                            .padding(16)

                            Divider()
                            HStack {
                                Spacer()
                                Button("Close") { creditsModal = nil }
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                        .frame(width: 380)
                    }
                    , alignment: .center
                )
                .transition(.opacity)
                .zIndex(100)
        }
    }

    private func statGrid(_ items: [(String, String, Color?)]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text(item.0)
                        .font(.system(size: 10, weight: .medium)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(item.2 ?? .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.background)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Actions
    private func supportsCredits(_ c: AICredential) -> Bool {
        ["deepseek", "openrouter"].contains(c.credentialType)
    }

    private func runTest(_ c: AICredential) async {
        testingID = c.id
        defer { testingID = nil }
        do {
            testResults[c.id] = try await state.api.testCredential(id: c.id)
        } catch {
            state.error = String(describing: error)
        }
    }

    private func revealKey(_ c: AICredential) async {
        revealingID = c.id
        defer { revealingID = nil }
        do {
            revealedID = c.id
            revealedKey = try await state.api.revealCredentialKey(id: c.id)
        } catch { state.error = String(describing: error) }
    }

    private func checkCredits(_ c: AICredential) async {
        checkingCreditsID = c.id
        defer { checkingCreditsID = nil }
        do {
            let result = try await state.api.typedCredentialCredits(id: c.id)
            // Convert typed enum to a simple result type for display
            switch result {
            case .openRouter(let total, let used, let remaining):
                creditsModal = (c.name, .openRouter(totalCredits: total, totalUsage: used, remaining: remaining))
            case .deepSeek(let available, let balances):
                creditsModal = (c.name, .deepSeek(isAvailable: available, balanceInfos: balances))
            @unknown default:
                break
            }
        } catch {
            state.error = String(describing: error)
        }
    }

    private func saveForm() async {
        showForm = false
        editing = nil
    }

    private func formatDate(_ value: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        guard let date = df.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return value }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: date)
    }
}

// Simple result enum for display (mirrors AICredentialCredits)
private enum AICredentialCreditsResult {
    case openRouter(totalCredits: Double, totalUsage: Double, remaining: Double)
    case deepSeek(isAvailable: Bool, balanceInfos: [AICredentialCredits.DeepSeekBalance])
}

// MARK: - AI Credential Form Content (inline)
private struct AICredentialFormContent: View {
    @EnvironmentObject private var state: AIState
    let credential: AICredential?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var type = "api_key"
    @State private var environment = "production"
    @State private var status = "active"
    @State private var apiKey = ""
    @State private var expiresAt = ""
    @State private var isShared = false
    @State private var saving = false
    @State private var error: String?

    private let environments = ["development", "staging", "production"]
    private let statuses = ["active", "inactive", "expired", "revoked", "testing"]

    private var credentialTypeOptions: [String] {
        let providerSlugs = state.providers.map(\.slug).filter { !$0.isEmpty }
        let existingTypes = state.credentials.map(\.credentialType).filter { !$0.isEmpty }
        return Array(Set(["api_key"] + providerSlugs + existingTypes + [type])).sorted()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                field("Name", text: $name, placeholder: "My OpenAI key")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type").font(.system(size: 12, weight: .medium))
                    Picker("", selection: $type) {
                        ForEach(credentialTypeOptions, id: \.self) { t in Text(t).tag(t) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Environment").font(.system(size: 12, weight: .medium))
                    Picker("", selection: $environment) {
                        ForEach(environments, id: \.self) { e in Text(e).tag(e) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key\(credential != nil ? " (leave blank to keep)" : "")")
                    .font(.system(size: 12, weight: .medium))
                SecureField("sk-…", text: $apiKey)
                    .font(.system(size: 13, design: .monospaced))
                    .textContentType(.none)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }

            HStack(spacing: 12) {
                field("Description", text: $description, placeholder: "Optional description")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status").font(.system(size: 12, weight: .medium))
                    Picker("", selection: $status) {
                        ForEach(statuses, id: \.self) { s in Text(s).tag(s) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expires at").font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: Binding(
                        get: { ISO8601DateFormatter().date(from: expiresAt) ?? Date() },
                        set: { expiresAt = ISO8601DateFormatter().string(from: $0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
            }

            HStack {
                Toggle("Shared", isOn: $isShared)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                Spacer()
                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    Button("Save") { Task { await save() } }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                        .disabled(name.trimmed.isEmpty || (credential == nil && apiKey.isEmpty) || saving)
                }
                .buttonStyle(.plain)
            }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
        .onAppear { load() }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium))
            TextField(placeholder, text: text)
                .font(.system(size: 13, design: mono ? .monospaced : .default))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }

    private func load() {
        guard let c = credential else { return }
        name = c.name; description = c.description ?? ""; type = c.credentialType
        environment = c.environment; status = c.status; isShared = c.isShared
        expiresAt = c.expiresAt ?? ""
    }

    private func save() async {
        saving = true; defer { saving = false }
        do {
            if let credential {
                var p = AICredentialUpdate()
                p.name = .value(name.trimmed); p.description = patchText(description)
                p.credentialType = .value(type); p.environment = .value(environment)
                p.status = .value(status); p.isShared = .value(isShared)
                p.expiresAt = expiresAt.trimmed.isEmpty ? .null : .value(expiresAt.trimmed)
                if !apiKey.isEmpty { p.credentialData = .value(["api_key": .string(apiKey)]) }
                _ = try await state.api.updateCredential(id: credential.id, p)
            } else {
                var c = AICredentialCreate(name: name.trimmed, credentialType: type, environment: environment, credentialData: ["api_key": .string(apiKey)])
                c.description = description.optional; c.expiresAt = expiresAt.optional
                _ = try await state.api.createCredential(c)
            }
            await state.reloadCredentials()
            await state.persistCatalogCache()
            onSave()
        } catch { self.error = String(describing: error) }
    }
}

// MARK: - AIInferenceView (q-hpc-panel tab bar + chip provider selection)
struct AIInferenceView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case chat, completions, embeddings, images, speech, transcription, video, music
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .chat: return "message.square"
            case .completions: return "doc.text"
            case .embeddings: return "bolt"
            case .images: return "photo"
            case .speech: return "mic"
            case .transcription: return "waveform"
            case .video: return "video"
            case .music: return "music.note"
            }
        }
    }

    @EnvironmentObject private var state: AIState
    @State private var kind: Kind = .chat
    @State private var selectedSlug = ""
    @State private var selectedModelID = ""
    @State private var credentialID: Int?
    @State private var response: String?
    @State private var error: String?
    @State private var loading = false

    // Chat state
    @State private var systemPrompt = ""
    @State private var chatPrompt = ""
    @State private var streaming = true
    // Completions
    @State private var complPrompt = ""
    // Embeddings
    @State private var embedInput = ""
    // Images
    @State private var imagePrompt = ""
    @State private var imageCount = 1
    @State private var imageSize = "1024x1024"
    // Speech
    @State private var speechInput = ""
    @State private var voice = "alloy"
    // Transcription
    @State private var transAudio = ""
    // Video
    @State private var videoPrompt = ""
    // Music
    @State private var musicPrompt = ""
    // Controls
    @State private var maxTokens = 1024
    @State private var temperature = 0.7

    private var credentialedSlugs: Set<String> {
        Set(state.activeCredentials.map(\.credentialType))
    }

    private var sortedActiveProviders: [AIProvider] {
        state.activeProviders.sorted { a, b in
            credentialedSlugs.contains(a.slug) && !credentialedSlugs.contains(b.slug)
        }
    }

    private var providerModels: [AIModel] {
        guard !selectedSlug.isEmpty else { return [] }
        let provider = state.providers.first { $0.slug == selectedSlug }
        guard let provider else { return [] }
        return state.models.filter { $0.providerID == provider.id }
    }

    private var isOnDeviceSelected: Bool {
        selectedSlug == AISDKProviderCatalog.onDeviceSlug
    }

    private var onDeviceAvailability: FoundationModelsAvailability {
        FoundationModelsAvailability.current
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.title2)
                        .foregroundStyle(AIV2Style.accentViolet)
                        .frame(width: 32, height: 32)
                        .background(AIV2Style.accentViolet.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inference Playground")
                            .font(.title2).fontWeight(.bold)
                        Text("Test AI inference across all modalities")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                if let error {
                    AIErrorBanner(message: error) { self.error = nil }
                }

                // Provider + Model chip selection
                VStack(spacing: 8) {
                    AISectionHeader(title: "Select Provider & Model")
                        .padding(.horizontal, 4)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 170), spacing: 6)], alignment: .leading, spacing: 6) {
                        AIChipToggle(
                            label: "Apple On-Device",
                            icon: "cpu",
                            isSelected: selectedSlug == AISDKProviderCatalog.onDeviceSlug,
                            accent: AIV2Style.accentViolet,
                            isCredentialed: false
                        ) {
                            selectedSlug = AISDKProviderCatalog.onDeviceSlug
                            selectedModelID = AISDKProviderCatalog.onDeviceSlug
                            response = nil
                            error = nil
                        }
                        ForEach(sortedActiveProviders) { p in
                            let isCredentialed = credentialedSlugs.contains(p.slug)
                            AIChipToggle(
                                label: p.name,
                                icon: isCredentialed ? "key.fill" : nil,
                                isSelected: selectedSlug == p.slug,
                                accent: AIV2Style.accentViolet,
                                isCredentialed: isCredentialed
                            ) {
                                selectedSlug = p.slug
                                selectedModelID = ""
                                response = nil
                                error = nil
                            }
                        }
                    }
                    if isOnDeviceSelected {
                        AIOnDeviceAvailabilityBanner(availability: onDeviceAvailability)
                    } else if !providerModels.isEmpty {
                        Picker("Model", selection: $selectedModelID) {
                            Text("Select a model…").tag("")
                            ForEach(providerModels) { m in
                                Text("\(m.name) (\(m.modelID))").tag(m.modelID)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    } else if !selectedSlug.isEmpty {
                        Text("No models for this provider.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

                // Tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Kind.allCases) { tab in
                            Button {
                                kind = tab; response = nil; error = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 10))
                                    Text(tab.title)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(kind == tab ? AIV2Style.accentViolet.opacity(0.1) : Color.clear)
                                .foregroundStyle(kind == tab ? AIV2Style.accentViolet : .secondary)
                                .overlay(
                                    Rectangle()
                                        .fill(kind == tab ? AIV2Style.accentViolet : Color.clear)
                                        .frame(height: 2),
                                    alignment: .bottom
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                // Tab content
                VStack(spacing: 12) {
                    switch kind {
                    case .chat:
                        chatForm
                    case .completions:
                        textForm("Prompt", text: $complPrompt)
                        genControls
                    case .embeddings:
                        textForm("Input text", text: $embedInput)
                    case .images:
                        textForm("Prompt", text: $imagePrompt)
                        HStack(spacing: 12) {
                            Stepper("Count: \(imageCount)", value: $imageCount, in: 1...8)
                                .font(.system(size: 12))
                            Picker("Size", selection: $imageSize) {
                                ForEach(["256x256", "512x512", "1024x1024", "1792x1024", "1024x1792"], id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    case .speech:
                        textForm("Text to speak", text: $speechInput)
                        Picker("Voice", selection: $voice) {
                            ForEach(["alloy", "echo", "fable", "onyx", "nova", "shimmer"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    case .transcription:
                        textForm("Audio (base64)", text: $transAudio)
                    case .video:
                        textForm("Prompt", text: $videoPrompt)
                    case .music:
                        textForm("Prompt", text: $musicPrompt)
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        if !isOnDeviceSelected {
                            AICredentialSelector(credentialID: $credentialID)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isOnDeviceSelected ? "Apple On-Device (Private)" : (selectedModelID.isEmpty ? "No model selected" : "\(providerModels.first(where: { $0.modelID == selectedModelID })?.name ?? selectedModelID)"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                Text("Transport: Swift AI SDK (direct)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.quaternary)
                            }
                            Spacer()
                            Button("Run") { Task { await runInference() } }
                                .disabled(
                                    loading || selectedSlug.isEmpty || selectedModelID.isEmpty
                                        || (isOnDeviceSelected && !onDeviceAvailability.isAvailable)
                                )
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

                // Response
                if let response {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Response")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Button { self.response = nil } label: {
                                Image(systemName: "xmark").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        Divider()
                        Text(response)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onChange(of: kind) { _, _ in response = nil; error = nil }
        .onChange(of: selectedSlug) { _, _ in selectedModelID = "" }
    }

    private var chatForm: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System prompt").font(.system(size: 12, weight: .medium))
                TextEditor(text: $systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 48)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("User message").font(.system(size: 12, weight: .medium))
                TextEditor(text: $chatPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 72)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            HStack(spacing: 16) {
                Toggle("Stream", isOn: $streaming)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))
                genControls
            }
        }
        .font(.system(size: 12))
    }

    private var genControls: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("Max tokens").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("", value: $maxTokens, format: .number)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            VStack(spacing: 2) {
                Text("Temperature").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("", value: $temperature, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private func textForm(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .medium))
            TextEditor(text: text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 80)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }

    private func runInference() async {
        loading = true; error = nil
        defer { loading = false }
        let client = AISDKInferenceClient(api: state.api)
        do {
            switch kind {
            case .chat:
                var messages: [AIChatMessage] = []
                if !systemPrompt.trimmed.isEmpty { messages.append(.init(role: "system", content: [.init(text: systemPrompt)])) }
                messages.append(.init(role: "user", content: [.init(text: chatPrompt)]))
                if streaming {
                    response = ""
                    let stream = try await client.chatStream(
                        providerSlug: selectedSlug,
                        model: selectedModelID,
                        messages: messages,
                        credentialID: credentialID,
                        providers: state.providers,
                        credentials: state.credentials,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )
                    for try await delta in stream {
                        response = (response ?? "") + delta
                    }
                } else {
                    response = prettyEncodable(try await client.chat(
                        providerSlug: selectedSlug,
                        model: selectedModelID,
                        messages: messages,
                        credentialID: credentialID,
                        providers: state.providers,
                        credentials: state.credentials,
                        maxTokens: maxTokens,
                        temperature: temperature
                    ))
                }
            case .completions:
                response = prettyEncodable(try await client.completion(
                    providerSlug: selectedSlug,
                    model: selectedModelID,
                    prompt: complPrompt,
                    credentialID: credentialID,
                    providers: state.providers,
                    credentials: state.credentials,
                    maxTokens: maxTokens,
                    temperature: temperature
                ))
            case .embeddings:
                let inputs = embedInput.split(whereSeparator: \.isNewline).map(String.init)
                response = prettyEncodable(try await client.embeddings(
                    providerSlug: selectedSlug,
                    model: selectedModelID,
                    input: inputs,
                    credentialID: credentialID,
                    providers: state.providers,
                    credentials: state.credentials
                ))
            case .images:
                response = prettyEncodable(try await client.image(
                    providerSlug: selectedSlug,
                    model: selectedModelID,
                    prompt: imagePrompt,
                    credentialID: credentialID,
                    providers: state.providers,
                    credentials: state.credentials,
                    n: imageCount,
                    size: imageSize
                ))
            case .speech, .transcription, .video, .music:
                throw AISDKInferenceError.unsupportedModality(
                    "\(kind.title) is not yet wired through the Swift AI SDK path. Use Chat, Completions, Embeddings, or Images."
                )
            }
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                self.error = description
            } else {
                self.error = String(describing: error)
            }
        }
    }
}

// MARK: - AIUsageView (stat cards + paginated log table)
struct AIUsageView: View {
    @EnvironmentObject private var state: AIState
    @State private var days = 30
    @State private var offset = 0
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.title2)
                        .foregroundStyle(AIV2Style.accentAmber)
                        .frame(width: 32, height: 32)
                        .background(AIV2Style.accentAmber.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usage Analytics")
                            .font(.title2).fontWeight(.bold)
                        Text("Track AI inference usage across all credentials")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Picker("Window", selection: $days) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                        Button {
                            loading = true
                            Task {
                                await state.loadUsage(days: days, offset: offset)
                                loading = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(loading)
                    }
                }
                .padding(.horizontal)

                if let error = state.usageStatsResource.error ?? state.usageResource.error {
                    AIErrorBanner(message: error) { Task { await state.loadUsage(days: days, offset: offset) } }
                }

                // Summary Stats
                if let s = state.usageStats {
                    AIStatsRow(values: [
                        ("Total Requests", s.resolvedRequests?.formatted() ?? "—", nil),
                        ("Success Rate", s.successRate.map { "\(($0 * 100).formatted(.number.precision(.fractionLength(1))))%" } ?? "—", AIV2Style.accentEmerald),
                        ("Total Tokens", s.totalTokens?.formatted() ?? "—", AIV2Style.accentBlue),
                        ("Avg Latency", s.avgLatencyMs.map { "\($0.formatted(.number.precision(.fractionLength(0))))ms" } ?? "—", AIV2Style.accentAmber),
                    ])
                } else if state.usageStatsResource.isLoading {
                    AIStatsRow(values: [("Loading", "…", nil), ("", "", nil), ("", "", nil), ("", "", nil)])
                }

                // Section header
                HStack {
                    AISectionHeader(title: "Request Log")
                    Spacer()
                    Button {
                        offset = 0
                        Task { await state.reloadUsage(offset: 0) }
                    } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Log table
                if state.usageResource.isLoading && state.usage.isEmpty {
                    AILoadingPlaceholder(count: 6)
                } else if state.usage.isEmpty {
                    AIEmptyCard(message: "No usage data yet. Run inference to see entries here.")
                } else {
                    VStack(spacing: 0) {
                        // Table header
                        HStack(spacing: 0) {
                            tableHeader("Time", width: 140)
                            tableHeader("Provider", width: 60)
                            tableHeaderFlex("Model")
                            tableHeader("Type", width: 60)
                            tableHeader("Tokens", width: 60, align: .trailing)
                            tableHeader("Latency", width: 70, align: .trailing)
                            tableHeader("", width: 30, align: .center)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.15))
                        .font(.system(size: 10, weight: .medium))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                        Divider()

                        ForEach(state.usage) { entry in
                            HStack(spacing: 0) {
                                tableCell(formatAbsoluteDate(entry.createdAt), width: 140, mono: true)
                                tableCell(entry.providerSlug, width: 60)
                                tableCellFlex(entry.modelID, mono: true)
                                    .lineLimit(1)
                                tableCell(entry.endpointType, width: 60)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                                tableCell("\((entry.promptTokens + entry.completionTokens).formatted())", width: 60, align: .trailing, mono: true)
                                tableCell("\(entry.latencyMs.formatted())ms", width: 70, align: .trailing, mono: true)
                                Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(entry.success ? Color.green : .red)
                                    .frame(width: 30)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                            Divider().padding(.leading, 12)
                        }

                        // Pagination
                        HStack(spacing: 8) {
                            Text("\(offset + 1)–\(offset + state.usage.count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Prev") {
                                offset = max(0, offset - 50)
                                Task { await state.reloadUsage(offset: offset) }
                            }
                            .disabled(offset == 0)
                            Button("Next") {
                                offset += 50
                                Task { await state.reloadUsage(offset: offset) }
                            }
                            .disabled(state.usage.count < 50)
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .task(id: days) {
            offset = 0
            await state.loadUsage(days: days)
        }
    }

    private func tableHeader(_ title: String, width: CGFloat, align: HorizontalAlignment = .leading) -> some View {
        Text(title)
            .frame(width: width, alignment: Alignment(horizontal: align, vertical: .center))
    }

    private func tableCell(_ text: String, width: CGFloat, align: HorizontalAlignment = .leading, mono: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, design: mono ? .monospaced : .default))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: Alignment(horizontal: align, vertical: .center))
    }

    private func tableHeaderFlex(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableCellFlex(_ text: String, mono: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, design: mono ? .monospaced : .default))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatAbsoluteDate(_ value: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        guard let date = df.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return value }
        let out = DateFormatter()
        out.dateStyle = .short
        out.timeStyle = .short
        return out.string(from: date)
    }
}

// MARK: - Public selectors (preserved from original)
public struct AICredentialSelector: View {
    @EnvironmentObject private var state: AIState
    @Binding private var credentialID: Int?
    public init(credentialID: Binding<Int?>) { _credentialID = credentialID }
    public var body: some View {
        Picker("Credential", selection: $credentialID) {
            Text("Automatic").tag(Int?.none)
            ForEach(state.activeCredentials) { credential in
                Text("\(credential.name) · \(credential.credentialType)").tag(Optional(credential.id))
            }
        }
    }
}

// MARK: - AIState convenience extensions
extension AIState {
    var activeProviders: [AIProvider] { providers.filter(\.active) }
    var activeCredentials: [AICredential] { credentials.filter { $0.status == "active" } }
}

// MARK: - Helpers
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var optional: String? { trimmed.isEmpty ? nil : trimmed }
}
private func patchText(_ value: String) -> AIPatch<String> { value.trimmed.isEmpty ? .null : .value(value.trimmed) }
private func prettyEncodable<T: Encodable>(_ value: T) -> String {
    guard let data = try? JSONEncoder().encode(value), let object = try? JSONSerialization.jsonObject(with: data), let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return String(describing: value) }
    return String(decoding: pretty, as: UTF8.self)
}
private func copyToPasteboard(_ value: String) {
#if os(macOS)
    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
#elseif os(iOS)
    UIPasteboard.general.string = value
#endif
}
