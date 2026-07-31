import SwiftUI
import DesignSystem
import WikiAPI

/// Form for creating or editing a wiki section.
public struct WikiSectionFormView: View {
    @Environment(\.cupertinoColors) private var colors

    let section: WikiSection?
    let sections: [WikiSection]
    let onSave: (Either<WikiSectionCreate, WikiSectionUpdate>) async -> Void
    let onCancel: (() -> Void)?

    @State private var slug = ""
    @State private var title = ""
    @State private var description = ""
    @State private var icon = ""
    @State private var parentId: Int?
    @State private var sortOrder = ""
    @State private var isPublic = true
    @State private var saving = false

    private var isEditing: Bool { section != nil }

    public init(
        section: WikiSection? = nil,
        sections: [WikiSection] = [],
        onSave: @escaping (Either<WikiSectionCreate, WikiSectionUpdate>) async -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.section = section
        self.sections = sections
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        Form {
            Section(isEditing ? "Edit Section" : "New Section") {
                LabeledContent("Slug") {
                    TextField("my-section", text: $slug)
                        .font(Theme.Typography.code)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                }

                LabeledContent("Title") {
                    TextField("My Section", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: title) { _, new in
                            guard !isEditing else { return }
                            slug = slugify(new)
                        }
                }

                LabeledContent("Description") {
                    TextEditor(text: $description)
                        .font(Theme.Typography.subheadline)
                        .frame(minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                                .stroke(colors.border, lineWidth: 1)
                        )
                }

                LabeledContent("Parent") {
                    Picker("Parent", selection: $parentId) {
                        Text("None (top level)").tag(nil as Int?)
                        ForEach(sections.filter { $0.id != section?.id }) { sec in
                            Text(sec.title).tag(sec.id as Int?)
                        }
                    }
                }

                LabeledContent("Icon") {
                    HStack {
                        TextField("🧪 or folder", text: $icon)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 120)
                        if !icon.isEmpty {
                            Text(icon)
                                .font(.title2)
                        }
                    }
                }

                LabeledContent("Sort Order") {
                    TextField("0", text: $sortOrder)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }

                Toggle("Public", isOn: $isPublic)
            }

            Section {
                HStack {
                    if let onCancel {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.secondary)
                    }
                    Button(isEditing ? "Save Changes" : "Create Section") {
                        Task { await save() }
                    }
                    .buttonStyle(.primary)
                    .disabled(title.isEmpty || slug.isEmpty || saving)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { populateFields() }
        .disabled(saving)
        .overlay {
            if saving {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .frame(minWidth: 400)
    }

    private func populateFields() {
        guard let section else { return }
        slug = section.slug
        title = section.title
        description = section.description ?? ""
        icon = section.icon ?? ""
        parentId = section.parentId
        sortOrder = String(section.sortOrder)
        isPublic = section.isPublic != 0
    }

    private func save() async {
        saving = true
        if isEditing, let section {
            let payload = WikiSectionUpdate(
                title: title != section.title ? title : nil,
                description: description != (section.description ?? "") ? description : nil,
                icon: icon != (section.icon ?? "") ? icon : nil,
                sortOrder: Int(sortOrder),
                isPublic: isPublic != (section.isPublic != 0) ? isPublic : nil,
                parentId: parentId
            )
            await onSave(.right(payload))
        } else {
            let payload = WikiSectionCreate(
                slug: slug,
                title: title,
                description: description.isEmpty ? nil : description,
                parentId: parentId,
                icon: icon.isEmpty ? nil : icon,
                sortOrder: Int(sortOrder),
                isPublic: isPublic
            )
            await onSave(.left(payload))
        }
        saving = false
    }

    private func slugify(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
