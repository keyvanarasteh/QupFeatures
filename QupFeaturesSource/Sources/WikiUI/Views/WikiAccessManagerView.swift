import SwiftUI
import DesignSystem
import WikiAPI

/// Grant / revoke per-user access for an article.
public struct WikiAccessManagerView: View {
    @Environment(\.cupertinoColors) private var colors
    let articleId: Int
    let isOwner: Bool
    let viewModel: WikiViewModel

    @State private var email = ""
    @State private var permission: WikiPermission = .view
    @State private var expiryDate: Date?
    @State private var showDatePicker = false

    public init(
        articleId: Int,
        isOwner: Bool,
        viewModel: WikiViewModel
    ) {
        self.articleId = articleId
        self.isOwner = isOwner
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader("Access Grants", systemImage: "person.badge.key")

            if viewModel.loading.access {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if !isOwner {
                Text("Only the article owner can manage access.")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                // Existing grants
                if viewModel.accessGrants.isEmpty {
                    Text("No access grants yet.")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                ForEach(viewModel.accessGrants) { grant in
                    grantRow(grant)
                }

                Divider()

                // Grant form
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Grant Access")
                        .font(Theme.Typography.captionEmphasized)

                    HStack(spacing: Theme.Spacing.sm) {
                        TextField("user@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .font(Theme.Typography.subheadline)
                            .disableAutocorrection(true)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
#if os(iOS)
                            .keyboardType(.emailAddress)
#endif

                        Picker("Permission", selection: $permission) {
                            Text("View").tag(WikiPermission.view)
                            Text("Edit").tag(WikiPermission.edit)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)

                        Button("Add") {
                            Task { await addGrant() }
                        }
                        .buttonStyle(.primary)
                        .controlSize(.small)
                        .disabled(email.isEmpty || viewModel.loading.access)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.lg)
        .task {
            await viewModel.loadAccessGrants(articleId: articleId)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Access manager")
    }

    @ViewBuilder
    private func grantRow(_ grant: WikiArticleAccess) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(grant.userEmail ?? "User #\(grant.userId)")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(colors.fg)
                    WikiPermissionBadge(grant.permission)
                }
                if let expires = grant.expiresAt {
                    Text("Expires: \(expires)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                Task { await viewModel.revokeAccess(grantId: grant.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(colors.danger)
            }
            .buttonStyle(.plain)
            .help("Revoke access")
            .disabled(viewModel.loading.access)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous))
    }

    private func addGrant() async {
        let expires: String? = expiryDate.flatMap { ISO8601DateFormatter().string(from: $0) }
        let payload = WikiAccessGrant(
            articleId: articleId,
            userId: 0, /* Backend resolves user by email */
            permission: permission,
            expiresAt: expires
        )
        await viewModel.grantAccess(payload)
        email = ""
    }
}

/// Compact permission badge.
private struct WikiPermissionBadge: View {
    let permission: WikiPermission

    init(_ permission: WikiPermission) {
        self.permission = permission
    }

    var body: some View {
        Text(permission == .edit ? "Edit" : "View")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(permission == .edit ? Color.orange : Color.blue)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                (permission == .edit ? Color.orange : Color.blue).opacity(0.12),
                in: Capsule(style: .continuous)
            )
    }
}
