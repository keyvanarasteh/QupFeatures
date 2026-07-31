import Foundation

/// Known OpenAI-compatible base URLs for provider slugs when the catalog row
/// does not supply `apiBaseURL`. Paths are the host roots the Swift AI SDK
/// OpenAI-compatible client appends `/chat/completions` etc. onto.
enum AISDKProviderCatalog: Sendable {
    /// Synthetic, credential-free slug for Apple's on-device model. Never
    /// backed by a core-api catalog row — resolved entirely client-side.
    static let onDeviceSlug = "apple-on-device"

    /// Whether `slug` refers to the on-device Apple provider rather than a
    /// network-reachable one.
    static func isOnDevice(_ slug: String) -> Bool {
        normalize(slug) == onDeviceSlug
    }

    /// Returns a base URL suitable for `createOpenAICompatible`, preferring the
    /// catalog value when present and non-empty.
    static func resolveBaseURL(slug: String, catalogBaseURL: String?) -> String? {
        if let catalogBaseURL, !catalogBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stripTrailingSlash(catalogBaseURL)
        }
        return defaultBaseURL(for: normalize(slug))
    }

    /// Providers whose native wire protocol is not OpenAI-compatible and need a
    /// dedicated SDK module instead of the generic compatible client.
    static func usesNativeProtocol(_ slug: String) -> NativeProtocol? {
        switch normalize(slug) {
        case "anthropic", "claude": return .anthropic
        case "google", "gemini", "google-generative-ai", "google-ai": return .google
        default: return nil
        }
    }

    enum NativeProtocol: String, Sendable {
        case anthropic
        case google
    }

    static func defaultBaseURL(for normalizedSlug: String) -> String? {
        switch normalizedSlug {
        case "openai":
            return "https://api.openai.com/v1"
        case "deepseek":
            return "https://api.deepseek.com"
        case "xai", "grok", "x-ai":
            return "https://api.x.ai/v1"
        case "groq":
            return "https://api.groq.com/openai/v1"
        case "openrouter":
            return "https://openrouter.ai/api/v1"
        case "together", "togetherai", "together-ai":
            return "https://api.together.xyz/v1"
        case "fireworks", "fireworks-ai":
            return "https://api.fireworks.ai/inference/v1"
        case "mistral", "mistralai":
            return "https://api.mistral.ai/v1"
        case "perplexity":
            return "https://api.perplexity.ai"
        case "cerebras":
            return "https://api.cerebras.ai/v1"
        case "moonshot", "moonshotai", "moonshot-ai":
            return "https://api.moonshot.cn/v1"
        case "deepinfra":
            return "https://api.deepinfra.com/v1/openai"
        case "baseten":
            return "https://inference.baseten.co/v1"
        case "vercel":
            return "https://api.vercel.ai/v1"
        case "ollama", "ollama-cloud":
            return "http://127.0.0.1:11434/v1"
        case "azure", "azure-openai":
            // Azure needs a deployment-specific host from the catalog/config.
            return nil
        default:
            return nil
        }
    }

    static func normalize(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func stripTrailingSlash(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("/") { result.removeLast() }
        return result
    }
}
