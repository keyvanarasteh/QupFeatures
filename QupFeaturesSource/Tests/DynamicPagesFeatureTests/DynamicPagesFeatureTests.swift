import Foundation
import Testing
import DynamicPagesAPI
import DynamicUI
@testable import DynamicPagesFeature

@Suite struct DynamicPageBodyCodecTests {
    @Test func blankTemplateDecodesAsDocument() throws {
        let obj = try DynamicPageBodyCodec.parseBodyObject(DynamicPageBodyCodec.blankTemplate)
        #expect(obj["schema_version"] != nil)
        #expect(obj["root"] != nil)
        _ = try DynamicDocument.decode(json: DynamicPageBodyCodec.blankTemplate)
    }

    @Test func demoAndHPCTemplatesDecode() throws {
        _ = try DynamicPageBodyCodec.parseBodyObject(DynamicPageBodyCodec.demoTemplate)
        _ = try DynamicPageBodyCodec.parseBodyObject(DynamicPageBodyCodec.hpcTemplate)
    }

    @Test func rejectsInvalidJSON() {
        let message = DynamicPageBodyCodec.validationMessage(for: "{ not json")
        #expect(message != nil)
    }

    @Test func rejectsEmpty() {
        #expect(DynamicPageBodyCodec.validationMessage(for: "   ") != nil)
    }

    @Test func prettyRoundTrip() throws {
        let obj = try DynamicPageBodyCodec.parseBodyObject(DynamicPageBodyCodec.demoTemplate)
        let pretty = try DynamicPageBodyCodec.prettyJSON(from: obj)
        let again = try DynamicPageBodyCodec.parseBodyObject(pretty)
        #expect(again["schema_version"] == obj["schema_version"])
    }
}

@Suite struct DynamicPagesStateTests {
    @Test @MainActor func loadAndSelectFromFixtures() async throws {
        let state = DynamicPagesPreviewFixtures.makeState()
        await state.loadPages()
        #expect(state.pages.count == 2)
        #expect(state.error == nil)

        await state.selectPage(id: 1)
        #expect(state.selectedPage?.pageKey == DynamicPagesPreviewFixtures.demoPageKey)
        #expect(state.draft.title == "Pages API Demo")
        #expect(state.bodyValidationError == nil)
        #expect(state.isDirty == false)
    }

    @Test @MainActor func dirtyTrackingAndDiscard() async throws {
        let state = DynamicPagesPreviewFixtures.makeState()
        await state.loadPages()
        await state.selectPage(id: 1)
        state.draft.title = "Changed"
        #expect(state.isDirty)
        state.discardDraft()
        #expect(!state.isDirty)
        #expect(state.draft.title == "Pages API Demo")
    }

    @Test @MainActor func saveRequiresValidBody() async throws {
        let state = DynamicPagesPreviewFixtures.makeState()
        await state.loadPages()
        await state.selectPage(id: 1)
        state.draft.bodyJSON = "{ bad"
        #expect(state.canSave == false)
        #expect(state.bodyValidationError != nil)
    }

    @Test @MainActor func createAndDelete() async throws {
        let state = DynamicPagesPreviewFixtures.makeState()
        let created = await state.createPage(DynamicPageInput(
            pageKey: "new_page",
            title: "New Page",
            body: try DynamicPageBodyCodec.parseBodyObject(DynamicPageBodyCodec.blankTemplate)
        ))
        #expect(created != nil)
        #expect(state.selectedPage?.id == 99)

        let deleted = await state.deletePage(id: 99)
        #expect(deleted)
        #expect(state.selectedPage == nil)
    }
}

@Suite struct DynamicPagesPreviewCatalogTests {
    @Test func surfacesIncludeScreensAndModal() {
        let surfaces = DynamicPagesPreviewCatalog.previewSurfaces
        #expect(surfaces.contains { $0.id == "screen.list" })
        #expect(surfaces.contains { $0.id == "screen.editor" })
        #expect(surfaces.contains { $0.id == "modal.create" })
        #expect(DynamicPagesPreviewCatalog.featureName == "DynamicPages")
    }

    @Test @MainActor func previewHostViewsResolve() {
        let list = DynamicPagesPreviewCatalog.previewHostView(for: "screen.list")
        let editor = DynamicPagesPreviewCatalog.previewHostView(for: "screen.editor")
        let modal = DynamicPagesPreviewCatalog.previewHostView(for: "modal.create")
        _ = list
        _ = editor
        _ = modal
    }
}
