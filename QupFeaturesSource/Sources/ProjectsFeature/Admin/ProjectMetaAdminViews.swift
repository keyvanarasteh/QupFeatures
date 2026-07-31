import DesignSystem
import ProjectsAPI
import SwiftUI

struct ProjectTypesAdminView: View {
    @EnvironmentObject private var state: ProjectsState
    @State private var editing: ProjectType?
    @State private var creating = false
    @State private var deleting: ProjectType?

    var body: some View {
        metaPage(title: "Project Types", count: state.types.count, create: { creating = true }) {
            ForEach(state.types) { item in
                metaRow(title: item.displayName, subtitle: item.typeName, color: item.color,
                        inactive: !item.isActive, edit: { editing = item }, delete: { deleting = item })
            }
        }
        .sheet(isPresented: $creating) { ProjectTypeFormSheet() }
        .sheet(item: $editing) { ProjectTypeFormSheet(type: $0) }
        .alert("Delete project type?", isPresented: deleteBinding($deleting), presenting: deleting) { item in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { _ = await state.deleteType(id: item.id) } }
        } message: { Text($0.displayName) }
    }
}

struct ProjectStatusesAdminView: View {
    @EnvironmentObject private var state: ProjectsState
    @State private var editing: ProjectStatus?
    @State private var creating = false
    @State private var deleting: ProjectStatus?

    var body: some View {
        metaPage(title: "Project Statuses", count: state.statuses.count, create: { creating = true }) {
            ForEach(state.statuses) { item in
                metaRow(title: item.displayName, subtitle: [item.statusName, item.statusType].compactMap { $0 }.joined(separator: " · "),
                        color: item.color, edit: { editing = item }, delete: { deleting = item })
            }
        }
        .sheet(isPresented: $creating) { ProjectStatusFormSheet() }
        .sheet(item: $editing) { ProjectStatusFormSheet(status: $0) }
        .alert("Delete project status?", isPresented: deleteBinding($deleting), presenting: deleting) { item in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { _ = await state.deleteStatus(id: item.id) } }
        } message: { Text($0.displayName) }
    }
}

struct ProjectRolesAdminView: View {
    @EnvironmentObject private var state: ProjectsState
    @State private var editing: ProjectRole?
    @State private var creating = false
    @State private var deleting: ProjectRole?

    var body: some View {
        metaPage(title: "Project Roles", count: state.roles.count, create: { creating = true }) {
            ForEach(state.roles) { item in
                metaRow(title: item.displayName, subtitle: "\(item.roleName)\(item.level.map { " · level \($0)" } ?? "")",
                        edit: { editing = item }, delete: { deleting = item })
            }
        }
        .sheet(isPresented: $creating) { ProjectRoleFormSheet() }
        .sheet(item: $editing) { ProjectRoleFormSheet(role: $0) }
        .alert("Delete project role?", isPresented: deleteBinding($deleting), presenting: deleting) { item in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { _ = await state.deleteRole(id: item.id) } }
        } message: { Text($0.displayName) }
    }
}

@MainActor
private func metaPage<Content: View>(title: String, count: Int, create: @escaping () -> Void,
                                     @ViewBuilder content: @escaping () -> Content) -> some View {
    PageContainer {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title, subtitle: "\(count) configured")
                Spacer()
                Button("New", systemImage: "plus", action: create).buttonStyle(.borderedProminent)
            }
            CardView(padding: 0) { VStack(spacing: 0) { content() } }
        }
    }
}

@MainActor
private func metaRow(title: String, subtitle: String, color: String? = nil, inactive: Bool = false,
                     edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
    HStack(spacing: Theme.Spacing.sm) {
        Circle().fill(color.flatMap(Color.init(hexString:)) ?? .secondary.opacity(0.25)).frame(width: 10, height: 10)
        VStack(alignment: .leading) {
            HStack { Text(title).font(Theme.Typography.bodyEmphasized); if inactive { StatusBadge("Inactive", tone: .neutral) } }
            Text(subtitle).font(Theme.Typography.caption).foregroundStyle(.secondary).monospaced()
        }
        Spacer()
        Button("Edit", systemImage: "pencil", action: edit).labelStyle(.iconOnly).buttonStyle(.plain)
        Button("Delete", systemImage: "trash", role: .destructive, action: delete).labelStyle(.iconOnly).buttonStyle(.plain)
    }
    .padding(Theme.Spacing.md)
}

@MainActor
private func deleteBinding<T: Sendable>(_ value: Binding<T?>) -> Binding<Bool> {
    Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
}

private struct ProjectTypeFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState
    let type: ProjectType?
    @State private var name: String
    @State private var display: String
    @State private var description: String
    @State private var icon: String
    @State private var color: String
    @State private var active: Bool

    init(type: ProjectType? = nil) {
        self.type = type
        _name = State(initialValue: type?.typeName ?? "")
        _display = State(initialValue: type?.displayName ?? "")
        _description = State(initialValue: type?.description ?? "")
        _icon = State(initialValue: type?.icon ?? "")
        _color = State(initialValue: type?.color ?? "")
        _active = State(initialValue: type?.isActive ?? true)
    }

    var body: some View { MetaForm(title: type == nil ? "New Type" : "Edit Type", canSave: !name.isEmpty && !display.isEmpty) {
        if type == nil { TextField("Type name (slug)", text: $name) }
        TextField("Display name", text: $display); TextField("Description", text: $description); TextField("Icon", text: $icon); TextField("Color", text: $color)
        if type != nil { Toggle("Active", isOn: $active) }
    } save: { await save() } }

    private func save() async {
        let ok = if let type { await state.updateType(id: type.id, .init(displayName: display, description: description.nilIfEmpty, icon: icon.nilIfEmpty, color: color.nilIfEmpty, isActive: active)) }
        else { await state.createType(.init(typeName: name, displayName: display, description: description.nilIfEmpty, icon: icon.nilIfEmpty, color: color.nilIfEmpty)) }
        if ok { dismiss() }
    }
}

private struct ProjectStatusFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState
    let status: ProjectStatus?
    @State private var name: String; @State private var display: String; @State private var type: String; @State private var color: String; @State private var order: String

    init(status: ProjectStatus? = nil) {
        self.status = status; _name = State(initialValue: status?.statusName ?? ""); _display = State(initialValue: status?.displayName ?? "")
        _type = State(initialValue: status?.statusType ?? ""); _color = State(initialValue: status?.color ?? ""); _order = State(initialValue: status?.sortOrder.map(String.init) ?? "")
    }

    var body: some View { MetaForm(title: status == nil ? "New Status" : "Edit Status", canSave: !name.isEmpty && !display.isEmpty) {
        if status == nil { TextField("Status name (slug)", text: $name) }
        TextField("Display name", text: $display); TextField("Status type", text: $type); TextField("Color", text: $color); TextField("Sort order", text: $order)
    } save: { await save() } }

    private func save() async {
        let ok = if let status { await state.updateStatus(id: status.id, .init(displayName: display, statusType: type.nilIfEmpty, color: color.nilIfEmpty, sortOrder: Int(order))) }
        else { await state.createStatus(.init(statusName: name, displayName: display, statusType: type.nilIfEmpty, color: color.nilIfEmpty, sortOrder: Int(order))) }
        if ok { dismiss() }
    }
}

private struct ProjectRoleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState
    let role: ProjectRole?
    @State private var name: String; @State private var display: String; @State private var level: String

    init(role: ProjectRole? = nil) {
        self.role = role; _name = State(initialValue: role?.roleName ?? ""); _display = State(initialValue: role?.displayName ?? ""); _level = State(initialValue: role?.level.map(String.init) ?? "")
    }

    var body: some View { MetaForm(title: role == nil ? "New Role" : "Edit Role", canSave: !name.isEmpty && !display.isEmpty) {
        if role == nil { TextField("Role name (slug)", text: $name) }
        TextField("Display name", text: $display); TextField("Level", text: $level)
    } save: { await save() } }

    private func save() async {
        let ok = if let role { await state.updateRole(id: role.id, .init(displayName: display, level: Int(level))) }
        else { await state.createRole(.init(roleName: name, displayName: display, level: Int(level))) }
        if ok { dismiss() }
    }
}

private struct MetaForm<Fields: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let canSave: Bool
    let fields: Fields
    let save: () async -> Void

    init(title: String, canSave: Bool, @ViewBuilder fields: () -> Fields, save: @escaping () async -> Void) {
        self.title = title
        self.canSave = canSave
        self.fields = fields()
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form { fields }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(!canSave) }
            }
        }
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
