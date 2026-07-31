import AIAPI
import FeatureContracts
import Foundation

/// Local GRDB-backed cache for AI v2 catalog rows (providers, models, credentials).
///
/// Storage goes through the feature-namespaced `FeatureSettingsClient`, which is
/// backed by `PersistenceSystem.SettingsStore` / `AppDatabase` — never secrets.
/// Credential **keys** are never written here; only metadata from `AICredential`.
public struct AILocalCacheStore: Sendable {
    public static let providersKey = "cache.providers"
    public static let modelsKey = "cache.models"
    public static let credentialsKey = "cache.credentials"
    public static let snapshotsKey = "cache.snapshots"
    public static let lastSyncedAtKey = "cache.lastSyncedAt"

    private let settings: FeatureSettingsClient

    public init(settings: FeatureSettingsClient) {
        self.settings = settings
    }

    // MARK: - Providers

    public func loadProviders() async throws -> [AIProvider]? {
        try await settings.value([AIProvider].self, forKey: Self.providersKey)
    }

    public func saveProviders(_ value: [AIProvider]) async throws {
        try await settings.setValue(value, forKey: Self.providersKey)
    }

    // MARK: - Models

    public func loadModels() async throws -> [AIModel]? {
        try await settings.value([AIModel].self, forKey: Self.modelsKey)
    }

    public func saveModels(_ value: [AIModel]) async throws {
        try await settings.setValue(value, forKey: Self.modelsKey)
    }

    // MARK: - Credentials (metadata only)

    public func loadCredentials() async throws -> [AICredential]? {
        try await settings.value([AICredential].self, forKey: Self.credentialsKey)
    }

    public func saveCredentials(_ value: [AICredential]) async throws {
        try await settings.setValue(value, forKey: Self.credentialsKey)
    }

    // MARK: - Catalog snapshots

    public func loadSnapshots() async throws -> [AICatalogSnapshot]? {
        try await settings.value([AICatalogSnapshot].self, forKey: Self.snapshotsKey)
    }

    public func saveSnapshots(_ value: [AICatalogSnapshot]) async throws {
        try await settings.setValue(value, forKey: Self.snapshotsKey)
    }

    // MARK: - Sync metadata

    public func loadLastSyncedAt() async throws -> Date? {
        try await settings.value(Date.self, forKey: Self.lastSyncedAtKey)
    }

    public func saveLastSyncedAt(_ date: Date = .now) async throws {
        try await settings.setValue(date, forKey: Self.lastSyncedAtKey)
    }

    /// Loads every catalog collection in one go (missing keys become empty).
    public func loadCatalog() async throws -> AILocalCatalog {
        AILocalCatalog(
            providers: try await loadProviders() ?? [],
            models: try await loadModels() ?? [],
            credentials: try await loadCredentials() ?? [],
            snapshots: try await loadSnapshots() ?? [],
            lastSyncedAt: try await loadLastSyncedAt()
        )
    }

    /// Atomically replaces the local catalog after a successful network sync.
    public func saveCatalog(
        providers: [AIProvider],
        models: [AIModel],
        credentials: [AICredential],
        snapshots: [AICatalogSnapshot]? = nil,
        syncedAt: Date = .now
    ) async throws {
        try await saveProviders(providers)
        try await saveModels(models)
        try await saveCredentials(credentials)
        if let snapshots {
            try await saveSnapshots(snapshots)
        }
        try await saveLastSyncedAt(syncedAt)
    }

    public func clear() async throws {
        try await settings.remove(Self.providersKey)
        try await settings.remove(Self.modelsKey)
        try await settings.remove(Self.credentialsKey)
        try await settings.remove(Self.snapshotsKey)
        try await settings.remove(Self.lastSyncedAtKey)
    }
}

/// Snapshot of the three AI v2 collections used by the playground and lists.
public struct AILocalCatalog: Sendable, Equatable {
    public var providers: [AIProvider]
    public var models: [AIModel]
    public var credentials: [AICredential]
    public var snapshots: [AICatalogSnapshot]
    public var lastSyncedAt: Date?

    public var isEmpty: Bool {
        providers.isEmpty && models.isEmpty && credentials.isEmpty
    }

    public init(
        providers: [AIProvider] = [],
        models: [AIModel] = [],
        credentials: [AICredential] = [],
        snapshots: [AICatalogSnapshot] = [],
        lastSyncedAt: Date? = nil
    ) {
        self.providers = providers
        self.models = models
        self.credentials = credentials
        self.snapshots = snapshots
        self.lastSyncedAt = lastSyncedAt
    }
}
