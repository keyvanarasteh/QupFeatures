import DesignSystem
import HostingerProxyAPI
import SwiftUI

// MARK: - Hosting View
//
// Ported from `q-hpc-panel/src/routes/hpanel/hosting/+page.svelte`.
// Hosting orders, websites, and database management.

struct HostingView: View {
    @ObservedObject var state: HostingerUIState
    @Environment(\.cupertinoColors) private var colors

    @State private var showDatabases = false
    @State private var dbUsername = ""
    @State private var dbUsernameInput = ""

    // New database form
    @State private var newDbName = ""
    @State private var newDbUser = ""
    @State private var newDbPass = ""
    @State private var formVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hostingOrders
                websitesSection
                databasesSection
            }
            .padding(Theme.Spacing.lg)
        }
        .background(colors.bg)
        .task {
            await state.loadOrders()
            await state.loadWebsites()
        }
    }

    // MARK: - Hosting Orders

    private var hostingOrders: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                sectionHeader(
                    systemImage: "server.rack",
                    title: "Hosting Orders",
                    count: state.orders.count,
                    loading: state.hostingLoading && state.orders.isEmpty
                ) {
                    Task { await state.loadOrders() }
                }

                if state.hostingLoading && state.orders.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if state.orders.isEmpty {
                    emptyState("No orders found.")
                } else {
                    ForEach(state.orders) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Order #\(order.id)")
                                        .font(.callout.weight(.medium))
                                    if let plan = order.plan {
                                        Text(plan)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(colors.primary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(colors.primary.opacity(0.1), in: Capsule())
                                    }
                                    if let status = order.status {
                                        Text(status)
                                            .font(.caption)
                                            .foregroundStyle(colors.mutedFg)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 12)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Websites

    private var websitesSection: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                sectionHeader(
                    systemImage: "globe",
                    title: "Websites",
                    count: state.websites.count,
                    loading: false
                ) {
                    Task { await state.loadWebsites() }
                }

                if state.websites.isEmpty {
                    emptyState("No websites found.")
                } else {
                    ForEach(Array(state.websites.enumerated()), id: \.offset) { _, site in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.domain ?? "—")
                                    .font(.callout.weight(.medium))
                                if let username = site.username {
                                    Text("username: \(username)")
                                        .font(.caption)
                                        .foregroundStyle(colors.mutedFg)
                                }
                                if let plan = site.plan {
                                    Text(plan)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(colors.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(colors.primary.opacity(0.1), in: Capsule())
                                }
                            }
                            Spacer()
                            if let username = site.username {
                                Button(action: {
                                    dbUsernameInput = username
                                    loadDbsFromInput()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "cylinder")
                                            .font(.caption2)
                                        Text("Databases")
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .foregroundStyle(colors.mutedFg)
                                    .background(colors.surface, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 12)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Databases

    private var databasesSection: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                sectionHeader(
                    systemImage: "cylinder",
                    title: "Databases",
                    count: nil,
                    loading: false
                ) {
                    // No refresh on header
                }

                VStack(spacing: 12) {
                    // Username input
                    HStack(spacing: 8) {
                        TextField("Hosting account username", text: $dbUsernameInput)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
                            .onSubmit { loadDbsFromInput() }

                        Button(action: loadDbsFromInput) {
                            Text("Load")
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(dbUsernameInput.trimmingCharacters(in: .whitespaces).isEmpty || state.hostingLoading)
                    }

                    if showDatabases && !dbUsername.isEmpty {
                        databaseList
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }

    private var databaseList: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("\(dbUsername) — \(state.databases.count) database(s)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(colors.mutedFg)
                Spacer()
                Button(action: { formVisible.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption2)
                        Text("New")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(colors.primary)
                    .background(colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Create form
            if formVisible {
                VStack(spacing: 8) {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                        TextField("Database name", text: $newDbName)
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))

                        TextField("DB username", text: $newDbUser)
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))

                        SecureField("Password", text: $newDbPass)
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                    }

                    HStack(spacing: 8) {
                        Button(action: createDb) {
                            Text("Create")
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(newDbName.isEmpty || newDbUser.isEmpty || newDbPass.isEmpty)

                        Button(action: { formVisible = false }) {
                            Text("Cancel")
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .foregroundStyle(colors.mutedFg)
                                .background(colors.surface, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: 8))
            }

            // Database list
            if state.databases.isEmpty {
                VStack(spacing: 4) {
                    Text("No databases found for \(dbUsername).")
                        .font(.callout)
                        .foregroundStyle(colors.mutedFg)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.databases) { db in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(db.name)
                                    .font(.callout.monospaced().weight(.medium))
                                if let username = db.username {
                                    Text("user: \(username)")
                                        .font(.caption)
                                        .foregroundStyle(colors.mutedFg)
                                }
                            }
                            Spacer()
                            Button(action: { deleteDb(db.name) }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(colors.danger)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 10)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
                .background(colors.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private func loadDbsFromInput() {
        let u = dbUsernameInput.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty else { return }
        dbUsername = u
        Task { await state.loadDatabases(username: u) }
        showDatabases = true
    }

    private func createDb() {
        guard !dbUsername.isEmpty, !newDbName.isEmpty, !newDbUser.isEmpty, !newDbPass.isEmpty else { return }
        let body: HostingerJSONObject = [
            "name": .string(newDbName),
            "username": .string(newDbUser),
            "password": .string(newDbPass),
        ]
        Task { await state.createDatabase(username: dbUsername, body: body) }
        newDbName = ""
        newDbUser = ""
        newDbPass = ""
        formVisible = false
    }

    private func deleteDb(_ name: String) {
        Task { await state.deleteDatabase(username: dbUsername, name: name) }
    }

    @ViewBuilder
    private func sectionHeader(systemImage: String, title: String, count: Int?, loading: Bool, refresh: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(colors.primary)
            Text(title)
                .font(.callout.weight(.semibold))
            if let count = count {
                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer()
            Button(action: refresh) {
                if loading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise").font(.caption2)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.callout)
                .foregroundStyle(colors.mutedFg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
