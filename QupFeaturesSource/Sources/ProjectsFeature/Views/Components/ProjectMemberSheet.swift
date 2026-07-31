import AdminAPI
import DesignSystem
import Networking
import ProjectsAPI
import SwiftUI

struct ProjectMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState

    private let api: AdminAPI
    let project: Project

    @State private var search = ""
    @State private var users: [AdminUser] = []
    @State private var selectedUserID: Int?
    @State private var roleID = 0
    @State private var loading = false
    @State private var localError: String?

    init(project: Project, client: APIClient) {
        self.project = project
        self.api = AdminAPI(client: client)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name or email", text: $search)
                        .onSubmit { Task { await loadUsers() } }
                    Button("Search") { Task { await loadUsers() } }
                        .disabled(search.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || loading)
                    if loading { ProgressView() }
                    ForEach(users) { user in
                        Button {
                            selectedUserID = user.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name ?? user.email)
                                    Text(user.email).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedUserID == user.id { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Find a user")
                } footer: {
                    Text("Search by name or email, then pick one result.")
                }
                Section {
                    Picker("Role", selection: $roleID) {
                        Text("Select a role").tag(0)
                        ForEach(state.roles) { Text($0.displayName).tag($0.id) }
                    }
                } header: {
                    Text("Project role")
                } footer: {
                    Text("Choose the role this member will have inside the project.")
                }
                if let error = localError ?? state.error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Member")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await add() } }
                        .disabled(selectedUserID == nil || roleID == 0 || state.loading.saving)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .frame(minWidth: 500, minHeight: 560)
    }

    private func loadUsers() async {
        loading = true
        defer { loading = false }
        localError = nil
        do {
            users = try await api.listUsers(filter: AdminUserFilter(search: search, perPage: 20)).items
                .filter { user in !(project.members ?? []).contains(where: { $0.userId == user.id }) }
        } catch {
            localError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func add() async {
        guard let selectedUserID else { return }
        if await state.addMember(projectId: project.id, userId: selectedUserID, roleId: roleID) {
            dismiss()
        }
    }
}
