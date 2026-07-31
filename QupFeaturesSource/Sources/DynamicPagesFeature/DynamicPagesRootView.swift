import DesignSystem
import DynamicPagesAPI
import Networking
import SwiftUI

/// Composition root: list | editor + live preview (adaptive).
public struct DynamicPagesRootView: View {
    @StateObject private var state: DynamicPagesState
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedPageId: Int?
    @State private var createOpen = false
    @State private var pendingDelete: DynamicPage?
    @State private var compactTab: CompactTab = .edit
    @State private var widthPreset: DynamicPagePreviewPane.WidthPreset = .auto

    private let initialPageId: Int?

    private enum CompactTab: String, CaseIterable, Identifiable {
        case edit
        case preview
        var id: String { rawValue }
        var title: String {
            switch self {
            case .edit: "Edit"
            case .preview: "Preview"
            }
        }
    }

    public init(client: APIClient, initialPageId: Int? = nil) {
        _state = StateObject(wrappedValue: DynamicPagesState(api: DynamicPagesAPI(client: client)))
        self.initialPageId = initialPageId
    }

    private var isRegularWidth: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    public var body: some View {
        NavigationSplitView {
            DynamicPagesListView(
                selectedPageId: $selectedPageId,
                onCreate: { createOpen = true }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 380)
        } detail: {
            detailBody
        }
        .environmentObject(state)
        .navigationTitle("Dynamic Pages")
        .task {
            await state.loadPages()
            if let initialPageId {
                selectedPageId = initialPageId
                await state.selectPage(id: initialPageId)
            }
        }
        .onChange(of: selectedPageId) { _, newValue in
            Task { await state.selectPage(id: newValue) }
        }
        .sheet(isPresented: $createOpen) {
            DynamicPageFormSheet { input in
                if let created = await state.createPage(input) {
                    selectedPageId = created.id
                    return true
                }
                return false
            }
            .environmentObject(state)
        }
        .confirmationDialog(
            "Delete \"\(pendingDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Page", role: .destructive) {
                if let page = pendingDelete {
                    Task {
                        if await state.deletePage(id: page.id) {
                            selectedPageId = nil
                        }
                    }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Soft-deletes the page. Its page_key becomes reusable.")
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        if state.selectedPage == nil && !state.loading.detail {
            EmptyStateView(
                title: "Select a page",
                message: "Choose a Dynamic Page to edit its metadata and body, or create a new one.",
                systemImage: "doc.richtext",
                actionTitle: "New Page",
                action: { createOpen = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.loading.detail && state.selectedPage == nil {
            ProgressView("Loading page…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                detailToolbar
                Divider()
                if isRegularWidth {
                    regularDetail
                } else {
                    compactDetail
                }
            }
        }
    }

    private var detailToolbar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let page = state.selectedPage {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(Theme.Typography.headline)
                    Text(page.pageKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(colors.mutedFg)
                }
            }
            Spacer()
            if state.isDirty {
                Text("Unsaved")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.warning)
                Button("Discard") { state.discardDraft() }
                    .disabled(state.loading.saving)
            }
            Button("Delete", role: .destructive) {
                pendingDelete = state.selectedPage
            }
            .disabled(state.selectedPage == nil || state.loading.saving)
            Button {
                Task { _ = await state.saveDraft() }
            } label: {
                if state.loading.saving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canSave || !state.isDirty)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var regularDetail: some View {
        #if os(macOS)
        HSplitView {
            DynamicPageEditorView(pageKeyEditable: false)
                .padding(Theme.Spacing.md)
                .frame(minWidth: 320)
            DynamicPagePreviewPane(
                bodyJSON: state.draft.bodyJSON,
                widthPreset: $widthPreset
            )
            .padding(Theme.Spacing.md)
            .frame(minWidth: 320)
        }
        #else
        HStack(alignment: .top, spacing: 0) {
            DynamicPageEditorView(pageKeyEditable: false)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
            Divider()
            DynamicPagePreviewPane(
                bodyJSON: state.draft.bodyJSON,
                widthPreset: $widthPreset
            )
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity)
        }
        #endif
    }

    private var compactDetail: some View {
        VStack(spacing: 0) {
            Picker("Pane", selection: $compactTab) {
                ForEach(CompactTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.md)

            switch compactTab {
            case .edit:
                DynamicPageEditorView(pageKeyEditable: false)
                    .padding(.horizontal, Theme.Spacing.md)
            case .preview:
                DynamicPagePreviewPane(
                    bodyJSON: state.draft.bodyJSON,
                    widthPreset: $widthPreset
                )
                .padding(Theme.Spacing.md)
            }
        }
    }
}
