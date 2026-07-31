import DesignSystem
import ProjectsAPI
import SwiftUI

/// Full project editor backed by core-api's existing `PUT /projects/{id}`.
/// The sections mirror q-hpc-panel's basic/repository/build/stack/runtime/
/// directories/tags tabs while using one native form.
struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState

    let project: Project

    @State private var name: String
    @State private var description: String
    @State private var typeID: Int
    @State private var statusID: Int
    @State private var version: String
    @State private var isPrivate: Bool
    @State private var isActive: Bool
    @State private var repositoryURL: String
    @State private var defaultBranch: String
    @State private var productionURL: String
    @State private var stagingURL: String
    @State private var previewURL: String
    @State private var autoDeploy: Bool
    @State private var deployOnPush: Bool
    @State private var deployBranch: String
    @State private var buildCommand: String
    @State private var installCommand: String
    @State private var startCommand: String
    @State private var devCommand: String
    @State private var testCommand: String
    @State private var lintCommand: String
    @State private var language: String
    @State private var languageVersion: String
    @State private var framework: String
    @State private var frameworkVersion: String
    @State private var packageManager: String
    @State private var packageManagerVersion: String
    @State private var nodeVersion: String
    @State private var pythonVersion: String
    @State private var rustVersion: String
    @State private var goVersion: String
    @State private var javaVersion: String
    @State private var phpVersion: String
    @State private var rubyVersion: String
    @State private var rootDirectory: String
    @State private var sourceDirectory: String
    @State private var outputDirectory: String
    @State private var publicDirectory: String
    @State private var tags: String
    @State private var techStack: String
    @State private var confidenceScore: Double

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description ?? "")
        _typeID = State(initialValue: project.projectTypeId ?? 0)
        _statusID = State(initialValue: project.statusId ?? 0)
        _version = State(initialValue: project.version ?? "")
        _isPrivate = State(initialValue: project.isPrivate)
        _isActive = State(initialValue: project.isActive)
        _repositoryURL = State(initialValue: project.repositoryUrl ?? "")
        _defaultBranch = State(initialValue: project.defaultBranch ?? "")
        _productionURL = State(initialValue: project.productionUrl ?? "")
        _stagingURL = State(initialValue: project.stagingUrl ?? "")
        _previewURL = State(initialValue: project.previewUrl ?? "")
        _autoDeploy = State(initialValue: project.autoDeploy ?? false)
        _deployOnPush = State(initialValue: project.deployOnPush ?? false)
        _deployBranch = State(initialValue: project.deployBranch ?? "")
        _buildCommand = State(initialValue: project.buildCommand ?? "")
        _installCommand = State(initialValue: project.installCommand ?? "")
        _startCommand = State(initialValue: project.startCommand ?? "")
        _devCommand = State(initialValue: project.devCommand ?? "")
        _testCommand = State(initialValue: project.testCommand ?? "")
        _lintCommand = State(initialValue: project.lintCommand ?? "")
        _language = State(initialValue: project.programmingLanguage ?? "")
        _languageVersion = State(initialValue: project.languageVersion ?? "")
        _framework = State(initialValue: project.framework ?? "")
        _frameworkVersion = State(initialValue: project.frameworkVersion ?? "")
        _packageManager = State(initialValue: project.packageManager ?? "")
        _packageManagerVersion = State(initialValue: project.packageManagerVersion ?? "")
        _nodeVersion = State(initialValue: project.nodeVersion ?? "")
        _pythonVersion = State(initialValue: project.pythonVersion ?? "")
        _rustVersion = State(initialValue: project.rustVersion ?? "")
        _goVersion = State(initialValue: project.goVersion ?? "")
        _javaVersion = State(initialValue: project.javaVersion ?? "")
        _phpVersion = State(initialValue: project.phpVersion ?? "")
        _rubyVersion = State(initialValue: project.rubyVersion ?? "")
        _rootDirectory = State(initialValue: project.rootDirectory ?? "")
        _sourceDirectory = State(initialValue: project.sourceDirectory ?? "")
        _outputDirectory = State(initialValue: project.outputDirectory ?? "")
        _publicDirectory = State(initialValue: project.publicDirectory ?? "")
        _tags = State(initialValue: (project.tags ?? []).joined(separator: ", "))
        _techStack = State(initialValue: (project.techStack ?? []).joined(separator: ", "))
        _confidenceScore = State(initialValue: Double(project.confidenceScore ?? 0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                    if !state.types.isEmpty {
                        Picker("Type", selection: $typeID) {
                            Text("Unchanged").tag(0)
                            ForEach(state.types) { Text($0.displayName).tag($0.id) }
                        }
                    }
                    if !state.statuses.isEmpty {
                        Picker("Status", selection: $statusID) {
                            Text("Unchanged").tag(0)
                            ForEach(state.statuses) { Text($0.displayName).tag($0.id) }
                        }
                    }
                    TextField("Project version", text: $version)
                    Toggle("Private", isOn: $isPrivate)
                    Toggle("Active", isOn: $isActive)
                }
                Section("Repository & URLs") {
                    TextField("Repository URL", text: $repositoryURL)
                    TextField("Default branch", text: $defaultBranch)
                    TextField("Production URL", text: $productionURL)
                    TextField("Staging URL", text: $stagingURL)
                    TextField("Preview URL", text: $previewURL)
                }
                Section("Deployment & commands") {
                    Toggle("Auto deploy", isOn: $autoDeploy)
                    Toggle("Deploy on push", isOn: $deployOnPush)
                    TextField("Deploy branch", text: $deployBranch)
                    commandField("Install", $installCommand)
                    commandField("Build", $buildCommand)
                    commandField("Start", $startCommand)
                    commandField("Development", $devCommand)
                    commandField("Test", $testCommand)
                    commandField("Lint", $lintCommand)
                }
                Section("Stack") {
                    TextField("Technology stack (comma-separated)", text: $techStack)
                    pairedFields("Language", $language, "Version", $languageVersion)
                    pairedFields("Framework", $framework, "Version", $frameworkVersion)
                    pairedFields("Package manager", $packageManager, "Version", $packageManagerVersion)
                    LabeledContent("Detection confidence") {
                        HStack {
                            Slider(value: $confidenceScore, in: 0...100, step: 1)
                            Text("\(Int(confidenceScore))%")
                                .monospacedDigit()
                                .frame(width: 42)
                        }
                    }
                }
                Section("Runtimes") {
                    pairedFields("Node", $nodeVersion, "Python", $pythonVersion)
                    pairedFields("Rust", $rustVersion, "Go", $goVersion)
                    pairedFields("Java", $javaVersion, "PHP", $phpVersion)
                    TextField("Ruby version", text: $rubyVersion)
                }
                Section("Directories") {
                    TextField("Root directory", text: $rootDirectory)
                    TextField("Source directory", text: $sourceDirectory)
                    TextField("Output directory", text: $outputDirectory)
                    TextField("Public directory", text: $publicDirectory)
                }
                Section("Tags") {
                    TextField("Comma-separated tags", text: $tags)
                }
                if let error = state.error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.trimmed.isEmpty || state.loading.saving)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .frame(minWidth: 560, minHeight: 720)
    }

    private func commandField(_ title: String, _ value: Binding<String>) -> some View {
        TextField("\(title) command", text: value)
            .font(.system(.body, design: .monospaced))
    }

    private func pairedFields(_ firstTitle: String, _ first: Binding<String>, _ secondTitle: String, _ second: Binding<String>) -> some View {
        HStack {
            TextField(firstTitle, text: first)
            TextField(secondTitle, text: second)
        }
    }

    private func save() async {
        var update = ProjectUpdate()
        update.name = name.trimmed
        update.description = description.nilIfBlank
        update.projectTypeId = typeID == 0 ? nil : typeID
        update.statusId = statusID == 0 ? nil : statusID
        update.version = version.nilIfBlank
        update.isPrivate = isPrivate
        update.isActive = isActive
        update.repositoryUrl = repositoryURL.nilIfBlank
        update.defaultBranch = defaultBranch.nilIfBlank
        update.productionUrl = productionURL.nilIfBlank
        update.stagingUrl = stagingURL.nilIfBlank
        update.previewUrl = previewURL.nilIfBlank
        update.autoDeploy = autoDeploy
        update.deployOnPush = deployOnPush
        update.deployBranch = deployBranch.nilIfBlank
        update.buildCommand = buildCommand.nilIfBlank
        update.installCommand = installCommand.nilIfBlank
        update.startCommand = startCommand.nilIfBlank
        update.devCommand = devCommand.nilIfBlank
        update.testCommand = testCommand.nilIfBlank
        update.lintCommand = lintCommand.nilIfBlank
        update.programmingLanguage = language.nilIfBlank
        update.languageVersion = languageVersion.nilIfBlank
        update.framework = framework.nilIfBlank
        update.frameworkVersion = frameworkVersion.nilIfBlank
        update.packageManager = packageManager.nilIfBlank
        update.packageManagerVersion = packageManagerVersion.nilIfBlank
        update.nodeVersion = nodeVersion.nilIfBlank
        update.pythonVersion = pythonVersion.nilIfBlank
        update.rustVersion = rustVersion.nilIfBlank
        update.goVersion = goVersion.nilIfBlank
        update.javaVersion = javaVersion.nilIfBlank
        update.phpVersion = phpVersion.nilIfBlank
        update.rubyVersion = rubyVersion.nilIfBlank
        update.rootDirectory = rootDirectory.nilIfBlank
        update.sourceDirectory = sourceDirectory.nilIfBlank
        update.outputDirectory = outputDirectory.nilIfBlank
        update.publicDirectory = publicDirectory.nilIfBlank
        update.tags = tags.csvValues
        update.techStack = techStack.csvValues
        update.confidenceScore = Int(confidenceScore)
        if await state.updateProject(id: project.id, update) != nil { dismiss() }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
    var csvValues: [String] {
        split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
    }
}
