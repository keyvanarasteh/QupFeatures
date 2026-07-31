import AIAPI
import Combine
import Foundation

public struct AIResourceState<Value: Sendable>: Sendable {
    public var value: Value
    public var isLoading = false
    public var error: String?

    public init(_ value: Value) { self.value = value }
}

/// Independent resource state for the AI v2 surface. A failure in one endpoint
/// never clears data successfully loaded from another endpoint.
///
/// Catalog collections (providers / models / credentials) are **hydrated from
/// the local GRDB cache first**, then refreshed from core-api. Successful
/// network reads and local mutations write through to the cache so Inference
/// and list UIs keep working offline with last-known data.
@MainActor public final class AIState: ObservableObject {
    @Published public private(set) var providerResource = AIResourceState<[AIProvider]>([])
    @Published public private(set) var modelResource = AIResourceState<[AIModel]>([])
    @Published public private(set) var credentialResource = AIResourceState<[AICredential]>([])
    @Published public private(set) var snapshotResource = AIResourceState<[AICatalogSnapshot]>([])
    @Published public private(set) var usageResource = AIResourceState<[AIUsageEntry]>([])
    @Published public private(set) var usageStatsResource = AIResourceState<AIUsageStats?>(nil)
    @Published public private(set) var syncing = false
    @Published public private(set) var syncResult: AICatalogSyncResult?
    @Published public private(set) var discoverResults: [String: AIDiscoverResult] = [:]
    @Published public private(set) var transientCredentialSecret: String?
    @Published public private(set) var lastSyncedAt: Date?
    @Published public private(set) var servingFromCache = false
    @Published public var error: String?

    public var providers: [AIProvider] { providerResource.value }
    public var models: [AIModel] { modelResource.value }
    public var credentials: [AICredential] { credentialResource.value }
    public var snapshots: [AICatalogSnapshot] { snapshotResource.value }
    public var usage: [AIUsageEntry] { usageResource.value }
    public var usageStats: AIUsageStats? { usageStatsResource.value }
    public var loading: Bool {
        providerResource.isLoading || modelResource.isLoading || credentialResource.isLoading || snapshotResource.isLoading
    }

    public let api: AIAPI
    public let cache: AILocalCacheStore?
    private var modelRequestID = 0

    public init(api: AIAPI, cache: AILocalCacheStore? = nil) {
        self.api = api
        self.cache = cache
    }

    private func message(_ error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    // MARK: - Load / sync

    /// Hydrate local cache immediately, then refresh from the network.
    public func loadAll() async {
        await hydrateFromCache()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.reloadProviders() }
            group.addTask { await self.reloadModels() }
            group.addTask { await self.reloadCredentials() }
            group.addTask { await self.reloadSnapshots() }
        }
        await stampSuccessfulCatalogSyncIfComplete()
    }

    /// Force a full catalog pull from core-api and rewrite the local cache.
    public func syncCatalogFromNetwork() async {
        syncing = true
        defer { syncing = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.reloadProviders(preferCacheOnFailure: false) }
            group.addTask { await self.reloadModels(preferCacheOnFailure: false) }
            group.addTask { await self.reloadCredentials(preferCacheOnFailure: false) }
            group.addTask { await self.reloadSnapshots(preferCacheOnFailure: false) }
        }
        await stampSuccessfulCatalogSyncIfComplete()
    }

    public func hydrateFromCache() async {
        guard let cache else { return }
        do {
            let catalog = try await cache.loadCatalog()
            if !catalog.providers.isEmpty {
                providerResource.value = catalog.providers
            }
            if !catalog.models.isEmpty {
                modelResource.value = catalog.models
            }
            if !catalog.credentials.isEmpty {
                credentialResource.value = catalog.credentials
            }
            if !catalog.snapshots.isEmpty {
                snapshotResource.value = catalog.snapshots
            }
            lastSyncedAt = catalog.lastSyncedAt
            servingFromCache = !catalog.isEmpty
        } catch {
            // Cache miss / decode failure is non-fatal; network load follows.
        }
    }

    public func reloadProviders(preferCacheOnFailure: Bool = true) async {
        providerResource.isLoading = true
        providerResource.error = nil
        do {
            let remote = try await api.listProviders()
            providerResource.value = remote
            servingFromCache = false
            try? await cache?.saveProviders(remote)
        } catch {
            if preferCacheOnFailure {
                await fallbackProviders(networkError: error)
            } else {
                providerResource.error = message(error)
            }
        }
        providerResource.isLoading = false
    }

    public func reloadModels(provider: String? = nil, preferCacheOnFailure: Bool = true) async {
        modelRequestID += 1
        let requestID = modelRequestID
        modelResource.isLoading = true
        modelResource.error = nil
        do {
            let loaded = try await api.listModels(providerSlug: provider)
            guard requestID == modelRequestID else { return }
            if let provider {
                // Merge provider-scoped list into the full cache.
                var merged = modelResource.value.filter { $0.providerSlug != provider }
                merged.append(contentsOf: loaded)
                modelResource.value = merged
                servingFromCache = false
                try? await cache?.saveModels(merged)
            } else {
                modelResource.value = loaded
                servingFromCache = false
                try? await cache?.saveModels(loaded)
            }
        } catch {
            guard requestID == modelRequestID else { return }
            if preferCacheOnFailure {
                await fallbackModels(networkError: error)
            } else {
                modelResource.error = message(error)
            }
        }
        if requestID == modelRequestID { modelResource.isLoading = false }
    }

    public func reloadModels(providers slugs: [String], preferCacheOnFailure: Bool = true) async {
        modelRequestID += 1
        let requestID = modelRequestID
        modelResource.isLoading = true
        modelResource.error = nil
        let api = api
        let results = await withTaskGroup(of: Result<[AIModel], Error>.self, returning: [Result<[AIModel], Error>].self) { group in
            for slug in slugs {
                group.addTask {
                    do { return .success(try await api.listModels(providerSlug: slug)) }
                    catch { return .failure(error) }
                }
            }
            var values: [Result<[AIModel], Error>] = []
            for await result in group { values.append(result) }
            return values
        }
        guard requestID == modelRequestID else { return }
        let successes = results.compactMap { try? $0.get() }
        if !successes.isEmpty {
            modelResource.value = successes.flatMap { $0 }
            servingFromCache = false
            try? await cache?.saveModels(modelResource.value)
        }
        if successes.count != results.count {
            if modelResource.value.isEmpty, preferCacheOnFailure {
                await fallbackModels(networkError: nil)
                if modelResource.value.isEmpty {
                    modelResource.error = "Some provider model lists could not be loaded."
                } else {
                    modelResource.error = "Network partial failure — showing cached models."
                    servingFromCache = true
                }
            } else if successes.isEmpty {
                modelResource.error = "Some provider model lists could not be loaded."
            } else {
                modelResource.error = "Some provider model lists could not be loaded."
            }
        }
        modelResource.isLoading = false
    }

    public func reloadCredentials(preferCacheOnFailure: Bool = true) async {
        credentialResource.isLoading = true
        credentialResource.error = nil
        do {
            let remote = try await api.listCredentials()
            credentialResource.value = remote
            servingFromCache = false
            try? await cache?.saveCredentials(remote)
        } catch {
            if preferCacheOnFailure {
                await fallbackCredentials(networkError: error)
            } else {
                credentialResource.error = message(error)
            }
        }
        credentialResource.isLoading = false
    }

    public func reloadSnapshots(preferCacheOnFailure: Bool = true) async {
        snapshotResource.isLoading = true
        snapshotResource.error = nil
        do {
            let remote = try await api.catalogSnapshots()
            snapshotResource.value = remote
            try? await cache?.saveSnapshots(remote)
        } catch {
            if preferCacheOnFailure, snapshotResource.value.isEmpty,
               let cached = try? await cache?.loadSnapshots(), !cached.isEmpty {
                snapshotResource.value = cached
                snapshotResource.error = "Offline — showing cached catalog snapshots."
            } else if snapshotResource.value.isEmpty {
                snapshotResource.error = message(error)
            } else {
                snapshotResource.error = message(error)
            }
        }
        snapshotResource.isLoading = false
    }

    public func loadUsage(days: Int, offset: Int = 0) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.reloadUsage(offset: offset) }
            group.addTask { await self.reloadUsageStats(days: days) }
        }
    }

    public func reloadUsage(offset: Int = 0) async {
        usageResource.isLoading = true
        usageResource.error = nil
        do { usageResource.value = try await api.usage(offset: offset) }
        catch { usageResource.error = message(error) }
        usageResource.isLoading = false
    }

    public func reloadUsageStats(days: Int) async {
        usageStatsResource.isLoading = true
        usageStatsResource.error = nil
        do { usageStatsResource.value = try await api.typedUsageStats(days: days) }
        catch { usageStatsResource.error = message(error) }
        usageStatsResource.isLoading = false
    }

    public func sync(source: AICatalogSource) async {
        syncing = true
        syncResult = nil
        defer { syncing = false }
        do {
            syncResult = try await api.syncCatalog(source: source)
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.reloadProviders() }
                group.addTask { await self.reloadModels() }
                group.addTask { await self.reloadSnapshots() }
            }
            await stampSuccessfulCatalogSyncIfComplete()
        } catch { self.error = message(error) }
    }

    public func discover(_ provider: AIProvider, credentialID: Int? = nil) async {
        do {
            discoverResults[provider.slug] = try await api.discoverModels(provider: provider.slug, credentialID: credentialID)
            await reloadModels()
        } catch { self.error = message(error) }
    }

    // MARK: - Mutations (write-through cache)

    public func deleteProvider(_ provider: AIProvider) async {
        do {
            try await api.deleteProvider(slug: provider.slug)
            providerResource.value.removeAll { $0.id == provider.id }
            modelResource.value.removeAll { $0.providerID == provider.id }
            try? await cache?.saveProviders(providerResource.value)
            try? await cache?.saveModels(modelResource.value)
        } catch { self.error = message(error) }
    }

    public func deleteModel(_ model: AIModel) async {
        do {
            try await api.deleteModel(id: model.id)
            modelResource.value.removeAll { $0.id == model.id }
            try? await cache?.saveModels(modelResource.value)
        } catch { self.error = message(error) }
    }

    public func deleteCredential(_ credential: AICredential) async {
        do {
            try await api.deleteCredential(id: credential.id)
            credentialResource.value.removeAll { $0.id == credential.id }
            try? await cache?.saveCredentials(credentialResource.value)
        } catch { self.error = message(error) }
    }

    /// Call after create/update forms mutate server state so the cache matches.
    public func persistCatalogCache() async {
        try? await cache?.saveCatalog(
            providers: providerResource.value,
            models: modelResource.value,
            credentials: credentialResource.value,
            snapshots: snapshotResource.value,
            syncedAt: lastSyncedAt ?? .now
        )
    }

    public func revealCredential(_ credential: AICredential) async {
        clearTransientSecrets()
        do { transientCredentialSecret = try await api.revealCredentialKey(id: credential.id) }
        catch { self.error = message(error) }
    }

    public func clearTransientSecrets() { transientCredentialSecret = nil }

    // MARK: - Private

    private func fallbackProviders(networkError: (any Error)?) async {
        if !providerResource.value.isEmpty {
            servingFromCache = true
            if let networkError {
                providerResource.error = "Network error — showing cached providers. \(message(networkError))"
            }
            return
        }
        if let cached = try? await cache?.loadProviders(), !cached.isEmpty {
            providerResource.value = cached
            servingFromCache = true
            providerResource.error = networkError.map { "Offline — showing cached providers. \(message($0))" }
                ?? "Offline — showing cached providers."
        } else if let networkError {
            providerResource.error = message(networkError)
        }
    }

    private func fallbackModels(networkError: (any Error)?) async {
        if !modelResource.value.isEmpty {
            servingFromCache = true
            if let networkError {
                modelResource.error = "Network error — showing cached models. \(message(networkError))"
            }
            return
        }
        if let cached = try? await cache?.loadModels(), !cached.isEmpty {
            modelResource.value = cached
            servingFromCache = true
            modelResource.error = networkError.map { "Offline — showing cached models. \(message($0))" }
                ?? "Offline — showing cached models."
        } else if let networkError {
            modelResource.error = message(networkError)
        }
    }

    private func fallbackCredentials(networkError: (any Error)?) async {
        if !credentialResource.value.isEmpty {
            servingFromCache = true
            if let networkError {
                credentialResource.error = "Network error — showing cached credentials. \(message(networkError))"
            }
            return
        }
        if let cached = try? await cache?.loadCredentials(), !cached.isEmpty {
            credentialResource.value = cached
            servingFromCache = true
            credentialResource.error = networkError.map { "Offline — showing cached credentials. \(message($0))" }
                ?? "Offline — showing cached credentials."
        } else if let networkError {
            credentialResource.error = message(networkError)
        }
    }

    private func stampSuccessfulCatalogSyncIfComplete() async {
        let catalogErrors = [
            providerResource.error,
            modelResource.error,
            credentialResource.error
        ].compactMap { $0 }
        // Only stamp when all three catalog collections refreshed without error.
        guard catalogErrors.isEmpty else { return }
        let now = Date.now
        lastSyncedAt = now
        servingFromCache = false
        try? await cache?.saveCatalog(
            providers: providerResource.value,
            models: modelResource.value,
            credentials: credentialResource.value,
            snapshots: snapshotResource.value,
            syncedAt: now
        )
    }
}
