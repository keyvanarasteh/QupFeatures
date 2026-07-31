import Foundation
import Networking

/// One synced CLI coding-agent account (`provider: "ai-agent"` row in
/// core-api's generic `credentials` table — same store as Kaggle/HPC/GitHub/
/// etc credentials; see core-api `CredentialController`/`CredentialService`
/// and migration `177_ai_agent_credential.sql`).
///
/// There's no real secret to vault here — `AgentAccount` tracks subscription
/// identity, not an API key — so writes never send `cred_secret`; core-api
/// stores a fixed placeholder in its place. Usage limits stay device-local:
/// each device re-checks its own CLI's currently authenticated identity and
/// never uploads that here.
public struct AIAgentCredential: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let provider: String
    public let label: String
    public let credKey: String
    public let extraData: ExtraData?
    public let isDefault: Bool
    public let createdAt: String
    public let updatedAt: String

    /// No explicit `CodingKeys` here: the shared `APIClient` decoder/encoder
    /// already applies `.convertFromSnakeCase`/`.convertToSnakeCase` globally
    /// (`QlineNetworking.makeClient`). Pairing that strategy with snake_case
    /// `CodingKeys` raw values breaks decoding — the container's keys get
    /// converted to camelCase first, so a requested key whose `stringValue`
    /// is still snake_case never matches. Plain camelCase properties round-trip
    /// correctly through the strategy alone, same as the outer `AIAgentCredential`.
    public struct ExtraData: Codable, Hashable, Sendable {
        public let agentProvider: String
        public let planTier: String?
        public let notes: String?
        public let remindBeforeReset: Bool
        public let alertNearLimit: Bool

        public init(agentProvider: String, planTier: String?, notes: String?, remindBeforeReset: Bool, alertNearLimit: Bool) {
            self.agentProvider = agentProvider
            self.planTier = planTier
            self.notes = notes
            self.remindBeforeReset = remindBeforeReset
            self.alertNearLimit = alertNearLimit
        }
    }
}

/// Request body for creating or updating an `ai-agent` credential.
/// `id == nil` creates a new row; `id` present updates one.
public struct AIAgentCredentialWrite: Encodable, Sendable {
    public var id: Int?
    public var provider: String
    public var label: String
    public var credKey: String
    public var extraData: AIAgentCredential.ExtraData
    public var isDefault: Bool

    public init(
        id: Int? = nil,
        label: String,
        credKey: String,
        extraData: AIAgentCredential.ExtraData,
        isDefault: Bool = false
    ) {
        self.id = id
        self.provider = "ai-agent"
        self.label = label
        self.credKey = credKey
        self.extraData = extraData
        self.isDefault = isDefault
    }
}

public enum AIAgentAPIError: LocalizedError, Sendable {
    case api(message: String, statusCode: Int?)

    public var errorDescription: String? {
        switch self {
        case let .api(message, code):
            if let code { return "[\(code)] \(message)" }
            return message
        }
    }
}

/// Generic multi-provider credentials store — `GET/POST/DELETE /api/credentials`
/// (same core-api backend as `HPCCredentialsAPI`/`IDSCredentialsAPI`). Scoped
/// here to the `ai-agent` provider only.
public final class AIAgentCredentialsAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func listCredentials() async throws -> [AIAgentCredential] {
        struct ListResponse: Decodable, Sendable { let credentials: [AIAgentCredential] }
        let response: ListResponse = try await perform(
            .get("/api/credentials", query: [URLQueryItem(name: "provider", value: "ai-agent")])
        )
        return response.credentials
    }

    @discardableResult
    public func saveCredential(_ write: AIAgentCredentialWrite) async throws -> Int {
        struct SaveResponse: Decodable, Sendable { let success: Bool; let id: Int }
        let response: SaveResponse = try await perform(.post("/api/credentials", body: .json(write)))
        return response.id
    }

    public func deleteCredential(id: Int) async throws {
        struct SuccessResponse: Decodable, Sendable { let success: Bool }
        let _: SuccessResponse = try await perform(
            Endpoint(method: .delete, path: "/api/credentials", query: [URLQueryItem(name: "id", value: "\(id)")])
        )
    }

    private func perform<T: Decodable & Sendable>(_ endpoint: Endpoint<T>) async throws -> T {
        do {
            return try await client.send(endpoint)
        } catch let error as NetworkError {
            throw mapped(error)
        }
    }

    private func mapped(_ error: NetworkError) -> AIAgentAPIError {
        switch error {
        case let .unacceptableStatus(code, data):
            return .api(message: parseErrorMessage(data) ?? "HTTP \(code)", statusCode: code)
        case let .decoding(underlying):
            return .api(message: "Decode failed: \(underlying.localizedDescription)", statusCode: nil)
        default:
            return .api(message: error.localizedDescription, statusCode: nil)
        }
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        struct Err: Decodable { let detail: String?; let message: String?; let error: String? }
        let err = try? JSONDecoder().decode(Err.self, from: data)
        let text = [err?.detail, err?.message, err?.error]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        if let text { return text }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - AgentAccount bridging

extension AgentAccount {
    /// Builds a brand-new local record from a remote row seen for the first
    /// time (synced in from another device).
    init(credential: AIAgentCredential) {
        self.init(
            provider: AgentProvider(rawValue: credential.extraData?.agentProvider ?? "") ?? .other,
            nickname: credential.label,
            email: credential.credKey,
            planTier: credential.extraData?.planTier,
            notes: credential.extraData?.notes,
            remindBeforeReset: credential.extraData?.remindBeforeReset ?? true,
            alertNearLimit: credential.extraData?.alertNearLimit ?? true,
            remoteCredentialID: credential.id
        )
    }

    /// Overwrites the synced identity fields from a remote row, preserving
    /// this record's local `id` and device-local `limits`.
    mutating func applyRemote(_ credential: AIAgentCredential) {
        if let agentProvider = credential.extraData.flatMap({ AgentProvider(rawValue: $0.agentProvider) }) {
            provider = agentProvider
        }
        nickname = credential.label
        email = credential.credKey
        planTier = credential.extraData?.planTier
        notes = credential.extraData?.notes
        remindBeforeReset = credential.extraData?.remindBeforeReset ?? remindBeforeReset
        alertNearLimit = credential.extraData?.alertNearLimit ?? alertNearLimit
    }

    func credentialWrite() -> AIAgentCredentialWrite {
        AIAgentCredentialWrite(
            id: remoteCredentialID,
            label: nickname,
            credKey: email,
            extraData: .init(
                agentProvider: provider.rawValue,
                planTier: planTier,
                notes: notes,
                remindBeforeReset: remindBeforeReset,
                alertNearLimit: alertNearLimit
            )
        )
    }
}
