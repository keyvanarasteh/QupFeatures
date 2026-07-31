import DesignSystem
import FoundationModelsKit
import ProjectsAPI
import SwiftUI

/// Ported from `routes/projects/+page.svelte`'s create modal as a `.sheet`,
/// matching `CreateTaskSheet`'s `*Sheet` naming convention. Required fields
/// (name/type/status) up front, advanced fields (repo URL, language,
/// framework, version, default branch) behind a disclosure, same as source.
struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors
    @EnvironmentObject private var state: ProjectsState

    @State private var name = ""
    @State private var typeID: Int?
    @State private var statusID: Int?
    @State private var description = ""
    @State private var isPrivate = false
    @State private var advancedOpen = false
    @State private var repositoryUrl = ""
    @State private var programmingLanguage = ""
    @State private var framework = ""
    @State private var version = ""
    @State private var defaultBranch = ""
    @State private var saving = false
    @State private var quickSpec = ""
    @State private var isParsingSpec = false

    let onCreated: (Project) -> Void

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && typeID != nil && statusID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if FoundationModelsAvailability.current.isAvailable {
                    Section {
                        TextEditor(text: $quickSpec)
                            .frame(minHeight: 60)
                        Button {
                            Task { await parseSpec() }
                        } label: {
                            if isParsingSpec {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Fill In With AI", systemImage: "sparkles")
                            }
                        }
                        .disabled(isParsingSpec || quickSpec.trimmingCharacters(in: .whitespaces).isEmpty)
                    } header: {
                        Text("Paste a spec or description")
                    } footer: {
                        Text("On-device suggestion — review the fields below before creating.")
                    }
                }
                Section("Name") {
                    TextField("My Project", text: $name)
                }
                Section("Type & status") {
                    Picker("Type", selection: $typeID) {
                        Text("Select type…").tag(Int?.none)
                        ForEach(state.types) { type in
                            Text(type.displayName).tag(Int?.some(type.id))
                        }
                    }
                    Picker("Status", selection: $statusID) {
                        Text("Select status…").tag(Int?.none)
                        ForEach(state.statuses) { status in
                            Text(status.displayName).tag(Int?.some(status.id))
                        }
                    }
                }
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                Section {
                    Toggle("Private project", isOn: $isPrivate)
                }
                Section {
                    DisclosureGroup("Advanced options", isExpanded: $advancedOpen) {
                        TextField("Repository URL", text: $repositoryUrl)
                        TextField("Language", text: $programmingLanguage)
                        TextField("Framework", text: $framework)
                        TextField("Version", text: $version)
                        TextField("Default branch", text: $defaultBranch)
                    }
                }
                if let error = state.error {
                    Section {
                        Text(error).foregroundStyle(colors.danger)
                    }
                }
            }
            .navigationTitle("New Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(saving || !canCreate)
                }
            }
        }
        .task { await state.loadMeta() }
    }

    private func create() async {
        guard let typeID, let statusID else { return }
        saving = true
        defer { saving = false }
        let created = await state.createProject(ProjectCreate(
            name: name.trimmingCharacters(in: .whitespaces),
            projectTypeId: typeID,
            statusId: statusID,
            description: description.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            isPrivate: isPrivate,
            repositoryUrl: repositoryUrl.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            programmingLanguage: programmingLanguage.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            framework: framework.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            version: version.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            defaultBranch: defaultBranch.trimmingCharacters(in: .whitespaces).nilIfEmpty
        ))
        guard let created else { return }
        onCreated(created)
        dismiss()
    }

    @MainActor
    private func parseSpec() async {
        isParsingSpec = true
        defer { isParsingSpec = false }
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return }
        do {
            let parsed = try await ProjectSpecParsing.parseSpec(quickSpec)
            name = parsed.name
            description = parsed.description
            if !parsed.programmingLanguage.isEmpty { programmingLanguage = parsed.programmingLanguage }
            if !parsed.framework.isEmpty { framework = parsed.framework }
        } catch {
            state.error = error.localizedDescription
        }
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
