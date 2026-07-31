import FeatureContracts
import SwiftUI

// MARK: - Surfaces

public enum DynamicPagesPreviewScreen: String, CaseIterable, Identifiable, Sendable {
    case list
    case editor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .list: "Pages list"
        case .editor: "Editor + preview"
        }
    }

    public var subtitle: String {
        switch self {
        case .list: "Search, filter, and select dynamic_pages"
        case .editor: "Metadata, JSON body, live DynamicHostView"
        }
    }

    public var systemImage: String {
        switch self {
        case .list: "doc.text.magnifyingglass"
        case .editor: "rectangle.split.2x1"
        }
    }

    public var sourceFile: String {
        switch self {
        case .list:
            "Packages/DynamicPagesFeature/Sources/DynamicPagesFeature/DynamicPagesListView.swift"
        case .editor:
            "Packages/DynamicPagesFeature/Sources/DynamicPagesFeature/DynamicPagesRootView.swift"
        }
    }
}

public enum DynamicPagesPreviewModal: String, CaseIterable, Identifiable, Sendable {
    case create

    public var id: String { rawValue }

    public var title: String { "New Page" }

    public var subtitle: String { "Create sheet with starter body templates" }

    public var systemImage: String { "plus.rectangle.on.folder" }

    public var sourceFile: String {
        "Packages/DynamicPagesFeature/Sources/DynamicPagesFeature/DynamicPageFormSheet.swift"
    }
}

// MARK: - Catalog

public enum DynamicPagesPreviewCatalog {
    public static let surfaces: [FeaturePreviewSurfaceDescriptor] = {
        var items: [FeaturePreviewSurfaceDescriptor] = DynamicPagesPreviewScreen.allCases.map { screen in
            FeaturePreviewSurfaceDescriptor(
                id: "screen.\(screen.rawValue)",
                kind: .screen,
                title: screen.title,
                subtitle: screen.subtitle,
                systemImage: screen.systemImage,
                sourceFile: screen.sourceFile
            )
        }
        items += DynamicPagesPreviewModal.allCases.map { modal in
            FeaturePreviewSurfaceDescriptor(
                id: "modal.\(modal.rawValue)",
                kind: .modal,
                title: modal.title,
                subtitle: modal.subtitle,
                systemImage: modal.systemImage,
                sourceFile: modal.sourceFile
            )
        }
        return items
    }()
}

extension DynamicPagesPreviewCatalog: FeaturePreviewCatalogProviding {
    public static let featureName = "DynamicPages"

    public static var previewSurfaces: [FeaturePreviewSurfaceDescriptor] {
        surfaces
    }

    @MainActor
    public static func previewHostView(for id: String) -> AnyView {
        if id.hasPrefix("modal.") {
            let raw = String(id.dropFirst("modal.".count))
            guard let modal = DynamicPagesPreviewModal(rawValue: raw) else {
                return AnyView(ContentUnavailableView("Unknown modal", systemImage: "questionmark.circle"))
            }
            return AnyView(DynamicPagesPreviewModalHost(modal: modal).id(id))
        }
        let raw = id.replacingOccurrences(of: "screen.", with: "")
        guard let screen = DynamicPagesPreviewScreen(rawValue: raw) else {
            return AnyView(ContentUnavailableView("Unknown surface", systemImage: "questionmark.circle"))
        }
        return AnyView(DynamicPagesPreviewHostView(screen: screen).id(id))
    }
}

// MARK: - Hosts

public struct DynamicPagesPreviewHostView: View {
    public let screen: DynamicPagesPreviewScreen

    public init(screen: DynamicPagesPreviewScreen) {
        self.screen = screen
    }

    public var body: some View {
        switch screen {
        case .list:
            DynamicPagesRootView(client: DynamicPagesPreviewFixtures.makeClient())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .editor:
            DynamicPagesRootView(
                client: DynamicPagesPreviewFixtures.makeClient(),
                initialPageId: 1
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

public struct DynamicPagesPreviewModalHost: View {
    public let modal: DynamicPagesPreviewModal

    public init(modal: DynamicPagesPreviewModal) {
        self.modal = modal
    }

    public var body: some View {
        switch modal {
        case .create:
            DynamicPageFormSheet { _ in true }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
