import DesignSystem
import DynamicPagesAPI
import SwiftUI

/// Create sheet: identity + starter body template.
public struct DynamicPageFormSheet: View {
    public enum Template: String, CaseIterable, Identifiable, Sendable {
        case blank
        case demo
        case hpc

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .blank: "Blank"
            case .demo: "Responsive demo"
            case .hpc: "HPC widgets"
            }
        }

        public var bodyJSON: String {
            switch self {
            case .blank: DynamicPageBodyCodec.blankTemplate
            case .demo: DynamicPageBodyCodec.demoTemplate
            case .hpc: DynamicPageBodyCodec.hpcTemplate
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors

    let onSubmit: (DynamicPageInput) async -> Bool

    @State private var pageKey = ""
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var scopeType = "user"
    @State private var visibility = "private"
    @State private var template: Template = .blank
    @State private var submitting = false

    private static let keyPattern = /^[a-z0-9][a-z0-9_-]{0,99}$/

    private var normalizedKey: String {
        pageKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSave: Bool {
        (try? Self.keyPattern.wholeMatch(in: normalizedKey)) != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !submitting
    }

    public init(onSubmit: @escaping (DynamicPageInput) async -> Bool) {
        self.onSubmit = onSubmit
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("my_page_key", text: $pageKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Title", text: $title)
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Scope") {
                    Picker("Scope", selection: $scopeType) {
                        Text("User (personal)").tag("user")
                        Text("Global (admin)").tag("global")
                    }
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                        Text("Unlisted").tag("unlisted")
                    }
                }
                Section("Starter body") {
                    Picker("Template", selection: $template) {
                        ForEach(Template.allCases) { Text($0.title).tag($0) }
                    }
                    Text("Creates a valid DynamicDocument you can edit after.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Create") { Task { await submit() } }
                            .disabled(!canSave)
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .frame(minWidth: 440, minHeight: 420)
    }

    @MainActor
    private func submit() async {
        guard canSave else { return }
        submitting = true
        defer { submitting = false }
        let body: [String: DynamicPageJSONValue]
        do {
            body = try DynamicPageBodyCodec.parseBodyObject(template.bodyJSON)
        } catch {
            return
        }
        let input = DynamicPageInput(
            pageKey: normalizedKey,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            scopeType: scopeType,
            visibility: visibility,
            schemaVersion: 1,
            body: body,
            isSystem: false,
            isActive: true
        )
        if await onSubmit(input) {
            dismiss()
        }
    }
}
