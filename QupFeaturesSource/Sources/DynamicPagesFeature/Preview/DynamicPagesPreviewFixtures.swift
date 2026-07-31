import Foundation
import DynamicPagesAPI
import Networking

/// Offline HTTP fixtures for Feature Catalog + unit tests.
public enum DynamicPagesPreviewFixtures {
    public static let demoPageKey = "cupertino_pages_api_demo"
    public static let hpcPageKey = "cupertino_hpc_preview"

    public static let demoBodyJSON = DynamicPageBodyCodec.demoTemplate
    public static let hpcBodyJSON = DynamicPageBodyCodec.hpcTemplate

    public static func makeClient() -> APIClient {
        APIClient(
            baseURL: URL(string: "https://dynamic-pages.preview.invalid")!,
            session: Session(),
            retryPolicy: .none,
            encoder: {
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                return encoder
            },
            decoder: {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return decoder
            },
            sleep: { _ in }
        )
    }

    @MainActor
    public static func makeState() -> DynamicPagesState {
        DynamicPagesState(api: DynamicPagesAPI(client: makeClient()))
    }

    // MARK: - Sample models (for direct view seeding if needed)

    public static var listPages: [DynamicPage] {
        [
            DynamicPage(
                id: 1,
                pageUuid: "d1a2b3c4-5e6f-4789-a012-3456789abcde",
                scopeType: "global",
                scopeKey: "global",
                pageKey: demoPageKey,
                title: "Pages API Demo",
                description: "First-class SDUI document",
                schemaVersion: 1,
                body: nil,
                isSystem: true,
                visibility: "public",
                isActive: true,
                etag: "etag-demo",
                isOwner: false
            ),
            DynamicPage(
                id: 2,
                pageUuid: "e2b3c4d5-6f70-4890-b123-456789abcdef",
                ownerUserId: 42,
                scopeType: "user",
                scopeKey: "user:42",
                pageKey: hpcPageKey,
                title: "HPC Widgets Preview",
                description: "Presentation-only cluster widgets",
                schemaVersion: 1,
                body: nil,
                isSystem: false,
                visibility: "private",
                isActive: true,
                etag: "etag-hpc",
                isOwner: true
            ),
        ]
    }
}

// MARK: - Session

private actor Session: HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        let method = request.httpMethod ?? "GET"
        let json = responseJSON(for: method, path: path, url: request.url)
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://dynamic-pages.preview.invalid")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }

    private func responseJSON(for method: String, path: String, url: URL?) -> [String: Any] {
        switch (method, path) {
        case ("GET", "/api/pages"):
            return [
                "status": "success",
                "success": true,
                "pages": DynamicPagesPreviewFixtures.listPages.map { pageListJSON($0) },
            ]

        case ("GET", let p) where p.hasPrefix("/api/pages/by-key/"):
            let key = String(p.dropFirst("/api/pages/by-key/".count))
            if key == DynamicPagesPreviewFixtures.hpcPageKey {
                return pageEnvelope(id: 2, pageKey: key, title: "HPC Widgets Preview",
                                    bodyJSON: DynamicPagesPreviewFixtures.hpcBodyJSON,
                                    scope: "user", visibility: "private", isSystem: false)
            }
            return pageEnvelope(id: 1, pageKey: DynamicPagesPreviewFixtures.demoPageKey,
                                title: "Pages API Demo", bodyJSON: DynamicPagesPreviewFixtures.demoBodyJSON,
                                scope: "global", visibility: "public", isSystem: true)

        case ("GET", let p) where p.hasPrefix("/api/pages/"):
            let id = Int(p.split(separator: "/").last.map(String.init) ?? "1") ?? 1
            if id == 2 {
                return pageEnvelope(id: 2, pageKey: DynamicPagesPreviewFixtures.hpcPageKey,
                                    title: "HPC Widgets Preview", bodyJSON: DynamicPagesPreviewFixtures.hpcBodyJSON,
                                    scope: "user", visibility: "private", isSystem: false)
            }
            if id == 1 {
                return pageEnvelope(id: 1, pageKey: DynamicPagesPreviewFixtures.demoPageKey,
                                    title: "Pages API Demo", bodyJSON: DynamicPagesPreviewFixtures.demoBodyJSON,
                                    scope: "global", visibility: "public", isSystem: true)
            }
            return pageEnvelope(id: id, pageKey: "new_page", title: "New Page",
                                bodyJSON: DynamicPageBodyCodec.blankTemplate,
                                scope: "user", visibility: "private", isSystem: false)

        case ("POST", "/api/pages"):
            return pageEnvelope(id: 99, pageKey: "new_page", title: "New Page",
                                bodyJSON: DynamicPagesPreviewFixtures.demoBodyJSON,
                                scope: "user", visibility: "private", isSystem: false)

        case ("PATCH", let p) where p.hasPrefix("/api/pages/"):
            let id = Int(p.split(separator: "/").last.map(String.init) ?? "1") ?? 1
            return pageEnvelope(id: id, pageKey: "updated_page", title: "Updated",
                                bodyJSON: DynamicPagesPreviewFixtures.demoBodyJSON,
                                scope: "user", visibility: "private", isSystem: false)

        case ("DELETE", _):
            return ["status": "success", "success": true]

        default:
            return ["status": "success", "success": true, "pages": []]
        }
    }

    private func pageListJSON(_ page: DynamicPage) -> [String: Any] {
        [
            "id": page.id,
            "page_uuid": page.pageUuid,
            "owner_user_id": page.ownerUserId as Any,
            "scope_type": page.scopeType,
            "scope_key": page.scopeKey,
            "page_key": page.pageKey,
            "title": page.title,
            "description": page.description as Any,
            "schema_version": page.schemaVersion,
            "is_system": page.isSystem,
            "visibility": page.visibility,
            "is_active": page.isActive,
            "etag": page.etag as Any,
            "is_owner": page.isOwner,
            "created_at": "2026-07-24 00:00:00",
            "updated_at": "2026-07-24 00:00:00",
        ]
    }

    private func pageEnvelope(
        id: Int,
        pageKey: String,
        title: String,
        bodyJSON: String,
        scope: String,
        visibility: String,
        isSystem: Bool
    ) -> [String: Any] {
        let bodyObject = (try? JSONSerialization.jsonObject(with: Data(bodyJSON.utf8))) as? [String: Any] ?? [:]
        return [
            "status": "success",
            "success": true,
            "page": [
                "id": id,
                "page_uuid": "preview-\(id)",
                "owner_user_id": scope == "user" ? 42 : NSNull(),
                "scope_type": scope,
                "scope_key": scope == "global" ? "global" : "user:42",
                "page_key": pageKey,
                "title": title,
                "description": "preview",
                "schema_version": 1,
                "body": bodyObject,
                "is_system": isSystem,
                "visibility": visibility,
                "is_active": true,
                "etag": "preview-etag",
                "is_owner": true,
                "created_at": "2026-07-24 00:00:00",
                "updated_at": "2026-07-24 00:00:00",
            ] as [String: Any],
        ]
    }
}
