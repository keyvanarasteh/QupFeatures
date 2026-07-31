import DesignSystem
import SwiftUI

/// Metadata fields + body JSON editor for the selected draft.
public struct DynamicPageEditorView: View {
    @EnvironmentObject private var state: DynamicPagesState
    @Environment(\.cupertinoColors) private var colors

    /// When true, page_key is read-only (edit existing).
    public var pageKeyEditable: Bool

    public init(pageKeyEditable: Bool = false) {
        self.pageKeyEditable = pageKeyEditable
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Editor")
                .font(Theme.Typography.subheadline.weight(.semibold))

            Form {
                Section("Identity") {
                    TextField("page_key", text: $state.draft.pageKey)
                        .disabled(!pageKeyEditable)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Title", text: $state.draft.title)
                    TextField("Description", text: $state.draft.description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Scope & status") {
                    Picker("Scope", selection: $state.draft.scopeType) {
                        Text("User").tag("user")
                        Text("Global").tag("global")
                    }
                    Picker("Visibility", selection: $state.draft.visibility) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                        Text("Unlisted").tag("unlisted")
                    }
                    Toggle("Active", isOn: $state.draft.isActive)
                    Toggle("System", isOn: $state.draft.isSystem)
                }

                Section("Body (DynamicDocument JSON)") {
                    if let err = state.bodyValidationError {
                        Text(err)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.danger)
                    }
                    TextEditor(text: $state.draft.bodyJSON)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}
