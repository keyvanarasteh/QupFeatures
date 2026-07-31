import AIAPI
import FeatureContracts
import Foundation
import Networking
import Testing
@testable import AIFeature

@Suite struct AIFeatureTests {
    @Test func exposesEveryMigratedSurface() {
        #expect(AISection.allCases.map(\.rawValue) == ["overview", "providers", "models", "credentials", "inference", "usage"])
    }

    @MainActor @Test func partialLoadKeepsSuccessfulResourcesAndIndependentErrors() async {
        let session = AIRouteSession(mode: .modelsFail)
        let state = AIState(api: AIAPI(client: testClient(session)))
        await state.loadAll()
        #expect(state.providers.count == 1)
        #expect(state.credentials.count == 1)
        #expect(state.snapshots.count == 1)
        #expect(state.models.isEmpty)
        #expect(state.modelResource.error != nil)
        #expect(state.providerResource.error == nil)
    }

    @MainActor @Test func staleProviderScopedModelResponseIsDiscarded() async {
        let session = AIRouteSession(mode: .staleModels)
        let state = AIState(api: AIAPI(client: testClient(session)))
        let slow = Task { await state.reloadModels(provider: "slow") }
        try? await Task.sleep(for: .milliseconds(40))
        await state.reloadModels(provider: "fast")
        await slow.value
        #expect(state.models.map(\.modelID) == ["fast-model"])
    }

    @MainActor @Test func secretIsTransientAndClearedExplicitly() async {
        let state = AIState(api: AIAPI(client: testClient(AIRouteSession(mode: .success))))
        await state.reloadCredentials()
        let credential = try! #require(state.credentials.first)
        await state.revealCredential(credential)
        #expect(state.transientCredentialSecret == "super-secret")
        state.clearTransientSecrets()
        #expect(state.transientCredentialSecret == nil)
    }

    @MainActor @Test func successfulDeletionMutatesCollectionAfterServerConfirmation() async {
        let state = AIState(api: AIAPI(client: testClient(AIRouteSession(mode: .success))))
        await state.reloadProviders()
        let provider = try! #require(state.providers.first)
        await state.deleteProvider(provider)
        #expect(state.providers.isEmpty)
    }

    @Test func providerCatalogResolvesKnownOpenAICompatibleBaseURLs() {
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "deepseek", catalogBaseURL: nil) == "https://api.deepseek.com")
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "xai", catalogBaseURL: nil) == "https://api.x.ai/v1")
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "openai", catalogBaseURL: nil) == "https://api.openai.com/v1")
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "groq", catalogBaseURL: nil) == "https://api.groq.com/openai/v1")
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "openrouter", catalogBaseURL: nil) == "https://openrouter.ai/api/v1")
    }

    @Test func providerCatalogPrefersCatalogBaseURLAndStripsSlash() {
        #expect(
            AISDKProviderCatalog.resolveBaseURL(slug: "custom", catalogBaseURL: "https://example.com/v1/")
                == "https://example.com/v1"
        )
    }

    @Test func providerCatalogMarksNativeProtocols() {
        #expect(AISDKProviderCatalog.usesNativeProtocol("anthropic") == .anthropic)
        #expect(AISDKProviderCatalog.usesNativeProtocol("google") == .google)
        #expect(AISDKProviderCatalog.usesNativeProtocol("deepseek") == nil)
        #expect(AISDKProviderCatalog.usesNativeProtocol("openai") == nil)
    }

    @Test func providerCatalogReturnsNilForUnknownSlugWithoutCatalogURL() {
        #expect(AISDKProviderCatalog.resolveBaseURL(slug: "totally-unknown-vendor", catalogBaseURL: nil) == nil)
    }

    @Test func providerCatalogRecognizesOnDeviceSlugCaseInsensitively() {
        #expect(AISDKProviderCatalog.isOnDevice("apple-on-device"))
        #expect(AISDKProviderCatalog.isOnDevice("  Apple-On-Device  "))
        #expect(!AISDKProviderCatalog.isOnDevice("openai"))
        #expect(!AISDKProviderCatalog.isOnDevice(""))
    }

    @Test func localCacheRoundTripsProvidersModelsAndCredentials() async throws {
        let memory = MemorySettings()
        let cache = AILocalCacheStore(settings: memory.client)
        let providers = [sampleProvider]
        let models = [sampleModel]
        let credentials = [sampleCredential]

        try await cache.saveCatalog(
            providers: providers,
            models: models,
            credentials: credentials,
            snapshots: [],
            syncedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let loaded = try await cache.loadCatalog()
        #expect(loaded.providers.map(\.slug) == ["openai"])
        #expect(loaded.models.map(\.modelID) == ["gpt-test"])
        #expect(loaded.credentials.map(\.id) == [3])
        #expect(loaded.lastSyncedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(loaded.isEmpty == false)
    }

    @MainActor @Test func loadAllHydratesFromCacheBeforeNetworkAndWritesThrough() async throws {
        let memory = MemorySettings()
        let cache = AILocalCacheStore(settings: memory.client)
        try await cache.saveProviders([sampleProvider])
        try await cache.saveModels([sampleModel])
        try await cache.saveCredentials([sampleCredential])
        try await cache.saveLastSyncedAt(Date(timeIntervalSince1970: 1_700_000_000))

        let session = AIRouteSession(mode: .success)
        let state = AIState(api: AIAPI(client: testClient(session)), cache: cache)
        await state.hydrateFromCache()
        #expect(state.providers.count == 1)
        #expect(state.models.map(\.modelID) == ["gpt-test"])
        #expect(state.credentials.count == 1)
        #expect(state.servingFromCache)
        #expect(state.lastSyncedAt == Date(timeIntervalSince1970: 1_700_000_000))

        await state.loadAll()
        #expect(state.providers.count == 1)
        #expect(state.servingFromCache == false)
        #expect(state.lastSyncedAt != nil)

        let after = try await cache.loadCatalog()
        #expect(after.providers.map(\.slug) == ["openai"])
        #expect(after.credentials.map(\.id) == [3])
    }

    @MainActor @Test func networkFailureKeepsCachedCatalog() async throws {
        let memory = MemorySettings()
        let cache = AILocalCacheStore(settings: memory.client)
        try await cache.saveProviders([sampleProvider])
        try await cache.saveModels([sampleModel])
        try await cache.saveCredentials([sampleCredential])

        let session = AIRouteSession(mode: .allFail)
        let state = AIState(api: AIAPI(client: testClient(session)), cache: cache)
        await state.hydrateFromCache()
        await state.reloadProviders()
        await state.reloadModels()
        await state.reloadCredentials()

        #expect(state.providers.map(\.slug) == ["openai"])
        #expect(state.models.map(\.modelID) == ["gpt-test"])
        #expect(state.credentials.map(\.id) == [3])
        #expect(state.servingFromCache)
        #expect(state.providerResource.error != nil)
    }

    @MainActor @Test func deleteProviderWritesThroughLocalCache() async throws {
        let memory = MemorySettings()
        let cache = AILocalCacheStore(settings: memory.client)
        let session = AIRouteSession(mode: .success)
        let state = AIState(api: AIAPI(client: testClient(session)), cache: cache)
        await state.reloadProviders()
        #expect((try await cache.loadProviders())?.count == 1)
        let provider = try! #require(state.providers.first)
        await state.deleteProvider(provider)
        #expect(state.providers.isEmpty)
        #expect((try await cache.loadProviders())?.isEmpty == true)
    }
}

// MARK: - Fixtures

private let fixtureDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

private let sampleProvider: AIProvider = {
    let json = #"{"id":1,"slug":"openai","name":"OpenAI","npm":"@ai/openai","env":["OPENAI_API_KEY"],"active":true,"is_self_hosted":false}"#
    return try! fixtureDecoder.decode(AIProvider.self, from: Data(json.utf8))
}()

private let sampleModel: AIModel = {
    let json = #"{"id":9,"provider_id":1,"provider_slug":"openai","model_id":"gpt-test","name":"GPT Test","currency":"USD","attachment":false,"reasoning":false,"tool_call":false,"open_weights":false,"release_date":"","last_updated":"","limit_context":100,"limit_output":10,"modalities_input":["text"],"modalities_output":["text"],"is_default":false,"cost_input":null,"cost_output":null,"cost_reasoning":null,"cost_cache_read":null,"cost_cache_write":null,"cost_input_audio":null,"cost_output_audio":null}"#
    return try! fixtureDecoder.decode(AIModel.self, from: Data(json.utf8))
}()

private let sampleCredential: AICredential = {
    let json = #"{"id":3,"user_id":9,"credential_uuid":"uuid","name":"OpenAI","description":null,"credential_type":"openai","status":"active","environment":"production","is_shared":false,"last_used_at":null,"expires_at":null,"created_at":"2026-01-01","updated_at":"2026-01-01"}"#
    return try! fixtureDecoder.decode(AICredential.self, from: Data(json.utf8))
}()

private func testClient(_ session: HTTPSession) -> APIClient {
    APIClient(baseURL: URL(string: "https://example.test")!, session: session, retryPolicy: .none,
              encoder: { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e },
              decoder: { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d })
}

/// In-memory stand-in for the GRDB-backed FeatureSettingsClient used by apps.
private actor MemorySettingsBox {
    private var storage: [String: Data] = [:]
    func get(_ key: String) -> Data? { storage[key] }
    func set(_ data: Data, for key: String) { storage[key] = data }
    func remove(_ key: String) { storage.removeValue(forKey: key) }
}

private struct MemorySettings: Sendable {
    private let box = MemorySettingsBox()

    var client: FeatureSettingsClient {
        let box = box
        return FeatureSettingsClient(
            data: { key in await box.get(key) },
            setData: { data, key in await box.set(data, for: key) },
            remove: { key in await box.remove(key) }
        )
    }
}

private actor AIRouteSession: HTTPSession {
    enum Mode { case success, modelsFail, staleModels, allFail }
    let mode: Mode
    init(mode: Mode) { self.mode = mode }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if mode == .allFail {
            return (
                Data(#"{"detail":"down"}"#.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            )
        }
        let path = request.url!.path
        if mode == .staleModels, path.contains("/providers/slow/models") { try await Task.sleep(for: .milliseconds(150)) }
        let status: Int
        let body: String
        switch (request.httpMethod ?? "GET", path) {
        case ("GET", "/api/ai/v2/providers"):
            status = 200; body = "[\(providerJSON)]"
        case ("GET", "/api/ai/v2/models"):
            status = mode == .modelsFail ? 500 : 200; body = mode == .modelsFail ? #"{"detail":"models unavailable"}"# : "[]"
        case ("GET", let value) where value.contains("/providers/slow/models"):
            status = 200; body = "[\(modelJSON(id: 1, modelID: "slow-model", providerSlug: "slow"))]"
        case ("GET", let value) where value.contains("/providers/fast/models"):
            status = 200; body = "[\(modelJSON(id: 2, modelID: "fast-model", providerSlug: "fast"))]"
        case ("GET", "/api/ai/v2/credentials"):
            status = 200; body = "[\(credentialJSON)]"
        case ("GET", "/api/ai/v2/catalog/snapshots"):
            status = 200; body = #"[{"id":1,"source":"api","source_url":"https://catalog","provider_count":1,"model_count":0,"inserted_count":0,"updated_count":0,"synced_by":null,"fetched_at":"2026-01-01"}]"#
        case ("POST", "/api/ai/v2/credentials/3/key"):
            status = 200; body = #"{"credential_data":{"api_key":"super-secret"}}"#
        case ("DELETE", "/api/ai/v2/providers/openai"):
            status = 204; body = ""
        default:
            status = 404; body = #"{"detail":"not stubbed"}"#
        }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    private var providerJSON: String { #"{"id":1,"slug":"openai","name":"OpenAI","npm":"@ai/openai","env":["OPENAI_API_KEY"],"active":true,"is_self_hosted":false}"# }
    private var credentialJSON: String { #"{"id":3,"user_id":9,"credential_uuid":"uuid","name":"OpenAI","description":null,"credential_type":"openai","status":"active","environment":"production","is_shared":false,"last_used_at":null,"expires_at":null,"created_at":"2026-01-01","updated_at":"2026-01-01"}"# }
    private func modelJSON(id: Int, modelID: String, providerSlug: String = "openai") -> String {
        """
        {"id":\(id),"provider_id":1,"provider_slug":"\(providerSlug)","model_id":"\(modelID)","name":"\(modelID)","currency":"USD","attachment":false,"reasoning":false,"tool_call":false,"open_weights":false,"release_date":"","last_updated":"","limit_context":100,"limit_output":10,"modalities_input":["text"],"modalities_output":["text"],"is_default":false,"cost_input":null,"cost_output":null,"cost_reasoning":null,"cost_cache_read":null,"cost_cache_write":null,"cost_input_audio":null,"cost_output_audio":null}
        """
    }
}
