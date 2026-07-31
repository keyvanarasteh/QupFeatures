import SwiftUI
import DesignSystem
import WikiAPI

/// Key-value meta field editor for article meta information.
public struct WikiMetaEditorView: View {
    @Environment(\.cupertinoColors) private var colors
    @Binding var meta: WikiArticleMeta?
    var onChange: ((WikiArticleMeta) -> Void)?

    @State private var customKeys: [String] = []
    @State private var customValues: [String: String] = [:]

    private let knownFields: [(key: String, label: String, icon: String)] = [
        ("pypiUrl", "PyPI URL", "link"),
        ("docsUrl", "Docs URL", "doc.text"),
        ("githubUrl", "GitHub URL", "curlybraces"),
        ("version", "Version", "tag"),
        ("license", "License", "doc.plaintext"),
    ]

    public init(meta: Binding<WikiArticleMeta?>, onChange: ((WikiArticleMeta) -> Void)? = nil) {
        _meta = meta
        self.onChange = onChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Meta Fields", systemImage: "list.clipboard")

            // Known fields
            ForEach(knownFields, id: \.key) { field in
                LabeledContent(field.label) {
                    TextField("", text: Binding(
                        get: { value(for: field.key) ?? "" },
                        set: { setValue(for: field.key, $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Typography.caption)
                    .disableAutocorrection(true)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                }
                .font(Theme.Typography.caption)
            }

            // Custom fields
            ForEach(customKeys, id: \.self) { key in
                HStack(spacing: Theme.Spacing.xs) {
                    TextField("Key", text: Binding(
                        get: { key },
                        set: { newKey in
                            let val = customValues[key]
                            customValues[newKey] = val
                            customValues.removeValue(forKey: key)
                            if let idx = customKeys.firstIndex(of: key) {
                                customKeys[idx] = newKey
                            }
                            emitChange()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Typography.caption)
                    .frame(maxWidth: 120)

                    TextField("Value", text: Binding(
                        get: { customValues[key] ?? "" },
                        set: { customValues[key] = $0; emitChange() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Typography.caption)
                    .disableAutocorrection(true)

                    Button { removeCustomField(key) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove field")
                }
            }

            Button("Add Field") {
                let key = "custom_\(customKeys.count + 1)"
                customKeys.append(key)
                customValues[key] = ""
            }
            .buttonStyle(.ghost)
            .font(Theme.Typography.caption)
        }
        .onAppear(perform: populateCustomFields)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meta editor")
    }

    private func value(for key: String) -> String? {
        guard let meta else { return nil }
        switch key {
        case "pypiUrl": return meta.pypiUrl
        case "docsUrl": return meta.docsUrl
        case "githubUrl": return meta.githubUrl
        case "version": return meta.version
        case "license": return meta.license
        default: return customValues[key]
        }
    }

    private func setValue(for key: String, _ val: String) {
        var m = meta ?? WikiArticleMeta()
        let newVal = val.isEmpty ? nil : val
        switch key {
        case "pypiUrl": m.pypiUrl = newVal
        case "docsUrl": m.docsUrl = newVal
        case "githubUrl": m.githubUrl = newVal
        case "version": m.version = newVal
        case "license": m.license = newVal
        default: customValues[key] = val
        }
        meta = m
        emitChange()
    }

    private func emitChange() {
        guard let meta else { return }
        onChange?(meta)
    }

    private func populateCustomFields() {
        // No simple way to detect custom fields from Codable struct.
        // Callers can pre-populate customKeys if needed.
    }

    private func removeCustomField(_ key: String) {
        customKeys.removeAll { $0 == key }
        customValues.removeValue(forKey: key)
        emitChange()
    }
}
