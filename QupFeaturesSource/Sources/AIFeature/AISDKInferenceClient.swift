import AIAPI
import AISDKProvider
import AnthropicProvider
import Foundation
import FoundationModelsKit
import GoogleProvider
import OpenAICompatibleProvider
import SwiftAISDK

/// Runs AI inference through the vendored Swift AI SDK (direct provider HTTP),
/// instead of proxying via core-api `/ai/v2/inference/*` and the local AI daemon.
///
/// Credential secrets are still fetched from core-api (`POST …/credentials/{id}/key`)
/// and used only for the in-flight request — never persisted by this client.
public struct AISDKInferenceClient: Sendable {
    private let api: AIAPI

    public init(api: AIAPI) {
        self.api = api
    }

    // MARK: - Public modalities

    public func chat(
        providerSlug: String,
        model: String,
        messages: [AIChatMessage],
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential],
        maxTokens: Int?,
        temperature: Double?
    ) async throws -> AISDKTextResult {
        let session = try await resolveSession(
            providerSlug: providerSlug,
            credentialID: credentialID,
            providers: providers,
            credentials: credentials
        )
        let languageModel = try session.languageModel(modelID: model)
        let promptMessages = try Self.mapMessages(messages)
        let result: DefaultGenerateTextResult<JSONValue> = try await generateText(
            model: languageModel,
            messages: promptMessages,
            experimentalOutput: nil as Output.Specification<JSONValue, JSONValue>?,
            settings: CallSettings(maxOutputTokens: maxTokens, temperature: temperature)
        )
        return Self.textResult(
            text: result.text,
            finishReason: String(describing: result.finishReason),
            usage: result.usage,
            provider: providerSlug,
            model: model
        )
    }

    public func chatStream(
        providerSlug: String,
        model: String,
        messages: [AIChatMessage],
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential],
        maxTokens: Int?,
        temperature: Double?
    ) async throws -> AsyncThrowingStream<String, Error> {
        let session = try await resolveSession(
            providerSlug: providerSlug,
            credentialID: credentialID,
            providers: providers,
            credentials: credentials
        )
        let languageModel = try session.languageModel(modelID: model)
        let promptMessages = try Self.mapMessages(messages)
        let stream: DefaultStreamTextResult<JSONValue, JSONValue> = try streamText(
            model: languageModel,
            system: nil,
            messages: promptMessages,
            experimentalOutput: nil as Output.Specification<JSONValue, JSONValue>?,
            settings: CallSettings(maxOutputTokens: maxTokens, temperature: temperature)
        )
        return stream.textStream
    }

    public func completion(
        providerSlug: String,
        model: String,
        prompt: String,
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential],
        maxTokens: Int?,
        temperature: Double?
    ) async throws -> AISDKTextResult {
        let session = try await resolveSession(
            providerSlug: providerSlug,
            credentialID: credentialID,
            providers: providers,
            credentials: credentials
        )
        let languageModel: LanguageModel
        if let completionModel = try? session.completionModel(modelID: model) {
            languageModel = completionModel
        } else {
            languageModel = try session.languageModel(modelID: model)
        }
        let result: DefaultGenerateTextResult<JSONValue> = try await generateText(
            model: languageModel,
            prompt: prompt,
            experimentalOutput: nil as Output.Specification<JSONValue, JSONValue>?,
            settings: CallSettings(maxOutputTokens: maxTokens, temperature: temperature)
        )
        return Self.textResult(
            text: result.text,
            finishReason: String(describing: result.finishReason),
            usage: result.usage,
            provider: providerSlug,
            model: model
        )
    }

    public func embeddings(
        providerSlug: String,
        model: String,
        input: [String],
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential]
    ) async throws -> AISDKEmbeddingResult {
        let session = try await resolveSession(
            providerSlug: providerSlug,
            credentialID: credentialID,
            providers: providers,
            credentials: credentials
        )
        let embeddingModel = try session.embeddingModel(modelID: model)
        let result = try await embedMany(model: embeddingModel, values: input)
        return AISDKEmbeddingResult(
            embeddings: result.embeddings,
            count: result.embeddings.count,
            dimensions: result.embeddings.first?.count ?? 0,
            provider: providerSlug,
            model: model,
            transport: "swift-ai-sdk"
        )
    }

    public func image(
        providerSlug: String,
        model: String,
        prompt: String,
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential],
        n: Int,
        size: String?
    ) async throws -> AISDKImageResult {
        let session = try await resolveSession(
            providerSlug: providerSlug,
            credentialID: credentialID,
            providers: providers,
            credentials: credentials
        )
        let imageModel = try session.imageModel(modelID: model)
        let result = try await SwiftAISDK.generateImage(
            model: imageModel,
            prompt: prompt,
            n: n,
            size: size
        )
        let images = result.images.map { $0.base64 }
        return AISDKImageResult(
            images: images,
            count: images.count,
            provider: providerSlug,
            model: model,
            transport: "swift-ai-sdk"
        )
    }

    // MARK: - Session resolution

    private func resolveSession(
        providerSlug: String,
        credentialID: Int?,
        providers: [AIProvider],
        credentials: [AICredential]
    ) async throws -> ProviderSession {
        let slug = AISDKProviderCatalog.normalize(providerSlug)
        guard !slug.isEmpty else {
            throw AISDKInferenceError.missingProvider
        }

        if AISDKProviderCatalog.isOnDevice(slug) {
            return .onDevice
        }

        let provider = providers.first { AISDKProviderCatalog.normalize($0.slug) == slug }
        let resolvedCredentialID = try resolveCredentialID(
            explicit: credentialID,
            provider: provider,
            providerSlug: slug,
            credentials: credentials
        )
        let apiKey = try await api.revealCredentialKey(id: resolvedCredentialID)
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AISDKInferenceError.emptyCredentialKey(credentialID: resolvedCredentialID)
        }

        if let native = AISDKProviderCatalog.usesNativeProtocol(slug) {
            switch native {
            case .anthropic:
                let anthropic = createAnthropic(
                    settings: AnthropicProviderSettings(baseURL: provider?.apiBaseURL, apiKey: apiKey)
                )
                return .nativeAnthropic(anthropic)
            case .google:
                let google = createGoogleGenerativeAI(
                    settings: GoogleProviderSettings(baseURL: provider?.apiBaseURL, apiKey: apiKey)
                )
                return .nativeGoogle(google)
            }
        }

        guard let baseURL = AISDKProviderCatalog.resolveBaseURL(slug: slug, catalogBaseURL: provider?.apiBaseURL) else {
            throw AISDKInferenceError.unknownProviderBaseURL(slug: slug)
        }

        let compatible = createOpenAICompatible(
            settings: OpenAICompatibleProviderSettings(
                baseURL: baseURL,
                name: slug,
                apiKey: apiKey,
                includeUsage: true
            )
        )
        return .openAICompatible(compatible)
    }

    private func resolveCredentialID(
        explicit: Int?,
        provider: AIProvider?,
        providerSlug: String,
        credentials: [AICredential]
    ) throws -> Int {
        if let explicit, explicit > 0 { return explicit }
        if let providerID = provider?.credentialID, providerID > 0 { return providerID }

        let active = credentials.filter { $0.status == "active" }
        if let match = active.first(where: { AISDKProviderCatalog.normalize($0.credentialType) == providerSlug }) {
            return match.id
        }
        if active.count == 1 { return active[0].id }
        throw AISDKInferenceError.noCredential(providerSlug: providerSlug)
    }

    private static func mapMessages(_ messages: [AIChatMessage]) throws -> [ModelMessage] {
        try messages.map { message in
            let text = message.content.compactMap(\.text).joined(separator: "\n")
            switch message.role.lowercased() {
            case "system":
                return .system(text)
            case "assistant":
                return .assistant(text)
            case "user":
                return .user(text)
            default:
                throw AISDKInferenceError.unsupportedRole(message.role)
            }
        }
    }

    private static func textResult(
        text: String,
        finishReason: String,
        usage: LanguageModelUsage,
        provider: String,
        model: String
    ) -> AISDKTextResult {
        AISDKTextResult(
            text: text,
            finishReason: finishReason,
            promptTokens: usage.inputTokens ?? 0,
            completionTokens: usage.outputTokens ?? 0,
            provider: provider,
            model: model,
            transport: "swift-ai-sdk"
        )
    }
}

// MARK: - Provider session

private enum ProviderSession {
    case openAICompatible(OpenAICompatibleProviderV4)
    case nativeAnthropic(AnthropicProviderV4)
    case nativeGoogle(GoogleProvider)
    /// Apple's on-device model. Carries no payload so this case (and the enum
    /// as a whole) stays free of `FoundationModelsLanguageModel`'s own
    /// `@available(iOS 26, macOS 26, *)` requirement — the availability check
    /// and the type itself are only touched inside the `if #available` arms
    /// below, at AIFeature's iOS 17 / macOS 14 floor.
    case onDevice

    func languageModel(modelID: String) throws -> LanguageModel {
        switch self {
        case .openAICompatible(let provider):
            return .v4(try provider.languageModel(modelId: modelID))
        case .nativeAnthropic(let provider):
            return .v4(try provider.languageModel(modelId: modelID))
        case .nativeGoogle(let provider):
            return .v3(try provider.languageModel(modelId: modelID))
        case .onDevice:
            if #available(iOS 26, macOS 26, *) {
                return .v4(FoundationModelsLanguageModel(modelId: modelID))
            }
            throw AISDKInferenceError.unsupportedModality(
                "The Apple on-device model requires iOS 26 / macOS 26 or later."
            )
        }
    }

    func completionModel(modelID: String) throws -> LanguageModel {
        switch self {
        case .openAICompatible(let provider):
            return .v4(try provider.completionModel(modelId: modelID))
        case .nativeAnthropic, .nativeGoogle, .onDevice:
            throw AISDKInferenceError.unsupportedModality(
                "Completions are not supported for this provider; use Chat instead."
            )
        }
    }

    func embeddingModel(modelID: String) throws -> EmbeddingModel {
        switch self {
        case .openAICompatible(let provider):
            return .v4(try provider.embeddingModel(modelId: modelID))
        case .nativeGoogle(let provider):
            return .v3(try provider.textEmbeddingModel(modelId: modelID))
        case .nativeAnthropic, .onDevice:
            throw AISDKInferenceError.unsupportedModality(
                "Embeddings are not supported for this provider via the Swift AI SDK path."
            )
        }
    }

    func imageModel(modelID: String) throws -> ImageModel {
        switch self {
        case .openAICompatible(let provider):
            return .v4(try provider.imageModel(modelId: modelID))
        case .nativeGoogle(let provider):
            return .v3(try provider.imageModel(modelId: modelID))
        case .nativeAnthropic, .onDevice:
            throw AISDKInferenceError.unsupportedModality(
                "Image generation is not supported for this provider via the Swift AI SDK path."
            )
        }
    }
}

// MARK: - Result types

public struct AISDKTextResult: Codable, Sendable, Equatable {
    public let text: String
    public let finishReason: String
    public let promptTokens: Int
    public let completionTokens: Int
    public let provider: String
    public let model: String
    public let transport: String
}

public struct AISDKEmbeddingResult: Codable, Sendable, Equatable {
    public let embeddings: [[Double]]
    public let count: Int
    public let dimensions: Int
    public let provider: String
    public let model: String
    public let transport: String
}

public struct AISDKImageResult: Codable, Sendable, Equatable {
    public let images: [String]
    public let count: Int
    public let provider: String
    public let model: String
    public let transport: String
}

// MARK: - Errors

public enum AISDKInferenceError: Error, LocalizedError, Sendable, Equatable {
    case missingProvider
    case noCredential(providerSlug: String)
    case emptyCredentialKey(credentialID: Int)
    case unknownProviderBaseURL(slug: String)
    case unsupportedRole(String)
    case unsupportedModality(String)

    public var errorDescription: String? {
        switch self {
        case .missingProvider:
            return "Select a provider before running inference."
        case .noCredential(let slug):
            return "No active credential for provider '\(slug)'. Create one under Credentials or pick a credential."
        case .emptyCredentialKey(let id):
            return "Credential #\(id) returned an empty API key."
        case .unknownProviderBaseURL(let slug):
            return "No API base URL for provider '\(slug)'. Set apiBaseURL on the provider record, or use a known OpenAI-compatible slug."
        case .unsupportedRole(let role):
            return "Unsupported chat role '\(role)'."
        case .unsupportedModality(let detail):
            return detail
        }
    }
}
