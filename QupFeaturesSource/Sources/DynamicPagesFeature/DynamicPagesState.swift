import Combine
import Foundation
import DynamicPagesAPI
import DynamicUI

/// Reactive state over `DynamicPagesAPI` — list, selection draft, CRUD.
@MainActor
public final class DynamicPagesState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var detail = false
        public var saving = false
    }

    /// In-memory editor draft for the selected page.
    public struct Draft: Equatable, Sendable {
        public var pageKey: String
        public var title: String
        public var description: String
        public var scopeType: String
        public var visibility: String
        public var isSystem: Bool
        public var isActive: Bool
        public var schemaVersion: Int
        public var bodyJSON: String

        public init(
            pageKey: String = "",
            title: String = "",
            description: String = "",
            scopeType: String = "user",
            visibility: String = "private",
            isSystem: Bool = false,
            isActive: Bool = true,
            schemaVersion: Int = 1,
            bodyJSON: String = DynamicPageBodyCodec.blankTemplate
        ) {
            self.pageKey = pageKey
            self.title = title
            self.description = description
            self.scopeType = scopeType
            self.visibility = visibility
            self.isSystem = isSystem
            self.isActive = isActive
            self.schemaVersion = schemaVersion
            self.bodyJSON = bodyJSON
        }

        public static func from(page: DynamicPage, bodyJSON: String) -> Draft {
            Draft(
                pageKey: page.pageKey,
                title: page.title,
                description: page.description ?? "",
                scopeType: page.scopeType,
                visibility: page.visibility,
                isSystem: page.isSystem,
                isActive: page.isActive,
                schemaVersion: page.schemaVersion,
                bodyJSON: bodyJSON
            )
        }
    }

    @Published public private(set) var pages: [DynamicPage] = []
    @Published public var filter = DynamicPageFilter()
    @Published public private(set) var selectedPage: DynamicPage?
    @Published public var draft = Draft()
    /// Snapshot used for dirty detection after load/save.
    @Published public private(set) var baselineDraft = Draft()
    @Published public private(set) var loading = LoadingState()
    @Published public var error: String?

    private let api: DynamicPagesAPI

    public init(api: DynamicPagesAPI) {
        self.api = api
    }

    public var isDirty: Bool { draft != baselineDraft }

    public var bodyValidationError: String? {
        DynamicPageBodyCodec.validationMessage(for: draft.bodyJSON)
    }

    public var canSave: Bool {
        !loading.saving
            && !draft.pageKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bodyValidationError == nil
    }

    private func setErr(_ error: any Error) {
        self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    public func clearErr() { error = nil }

    // MARK: - List

    public func loadPages(_ patch: DynamicPageFilter? = nil) async {
        if let patch { filter = patch }
        loading.list = true
        defer { loading.list = false }
        do {
            pages = try await api.listPages(filter: filter)
            clearErr()
        } catch {
            setErr(error)
        }
    }

    // MARK: - Selection

    public func selectPage(id: Int?) async {
        guard let id else {
            selectedPage = nil
            draft = Draft()
            baselineDraft = draft
            return
        }
        if selectedPage?.id == id, selectedPage?.body != nil { return }

        loading.detail = true
        defer { loading.detail = false }
        do {
            let page = try await api.getPage(id: id)
            selectedPage = page
            let bodyJSON = (try? DynamicPageBodyCodec.prettyJSON(from: page.body))
                ?? DynamicPageBodyCodec.blankTemplate
            draft = Draft.from(page: page, bodyJSON: bodyJSON)
            baselineDraft = draft
            clearErr()
        } catch {
            setErr(error)
        }
    }

    public func discardDraft() {
        draft = baselineDraft
    }

    // MARK: - CRUD

    public func createPage(_ input: DynamicPageInput) async -> DynamicPage? {
        loading.saving = true
        defer { loading.saving = false }
        do {
            let page = try await api.createPage(input)
            await loadPages()
            await selectPage(id: page.id)
            return page
        } catch {
            setErr(error)
            return nil
        }
    }

    public func saveDraft() async -> Bool {
        guard let selected = selectedPage else { return false }
        loading.saving = true
        defer { loading.saving = false }
        do {
            let body = try DynamicPageBodyCodec.parseBodyObject(draft.bodyJSON)
            let input = DynamicPageInput(
                pageKey: draft.pageKey.trimmingCharacters(in: .whitespacesAndNewlines),
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                scopeType: draft.scopeType,
                visibility: draft.visibility,
                schemaVersion: draft.schemaVersion,
                body: body,
                isSystem: draft.isSystem,
                isActive: draft.isActive
            )
            let page = try await api.updatePage(id: selected.id, input)
            selectedPage = page
            // Keep editor body as-is (pretty) but refresh baseline from response when body returned.
            if page.body != nil {
                let bodyJSON = (try? DynamicPageBodyCodec.prettyJSON(from: page.body)) ?? draft.bodyJSON
                draft = Draft.from(page: page, bodyJSON: bodyJSON)
            } else {
                draft = Draft.from(page: page, bodyJSON: draft.bodyJSON)
            }
            baselineDraft = draft
            pages = pages.map { $0.id == page.id ? page.withoutBodyPreferringListFields(from: $0) : $0 }
            // Refresh list titles etc.
            await loadPages()
            // Re-apply selection metadata without re-fetch if still selected
            if selectedPage?.id == page.id {
                // list reload may have cleared body — keep selected with our draft body
            }
            clearErr()
            return true
        } catch {
            setErr(error)
            return false
        }
    }

    public func deletePage(id: Int) async -> Bool {
        loading.saving = true
        defer { loading.saving = false }
        do {
            try await api.deletePage(id: id)
            if selectedPage?.id == id {
                selectedPage = nil
                draft = Draft()
                baselineDraft = draft
            }
            await loadPages()
            clearErr()
            return true
        } catch {
            setErr(error)
            return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

private extension DynamicPage {
    /// List rows often omit body; preserve list entry shape after patch.
    func withoutBodyPreferringListFields(from listRow: DynamicPage) -> DynamicPage {
        DynamicPage(
            id: id,
            pageUuid: pageUuid,
            ownerUserId: ownerUserId,
            scopeType: scopeType,
            scopeKey: scopeKey,
            pageKey: pageKey,
            title: title,
            description: description,
            schemaVersion: schemaVersion,
            body: nil,
            isSystem: isSystem,
            visibility: visibility,
            isActive: isActive,
            etag: etag,
            isOwner: isOwner,
            createdAt: createdAt ?? listRow.createdAt,
            updatedAt: updatedAt ?? listRow.updatedAt
        )
    }
}
