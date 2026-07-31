import DesignSystem
import SwiftUI

struct AgentAccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let account: AgentAccount?
    let onSave: (AgentAccount) async -> Void

    @State private var provider: AgentProvider
    @State private var nickname: String
    @State private var email: String
    @State private var planTier: String
    @State private var notes: String
    @State private var limits: [UsageLimit]
    @State private var remindBeforeReset: Bool
    @State private var alertNearLimit: Bool
    @State private var isSaving = false

    private var isEditing: Bool { account != nil }

    init(account: AgentAccount?, onSave: @escaping (AgentAccount) async -> Void) {
        self.account = account
        self.onSave = onSave
        _provider = State(initialValue: account?.provider ?? .claude)
        _nickname = State(initialValue: account?.nickname ?? "")
        _email = State(initialValue: account?.email ?? "")
        _planTier = State(initialValue: account?.planTier ?? "")
        _notes = State(initialValue: account?.notes ?? "")
        _limits = State(initialValue: account?.limits ?? [])
        _remindBeforeReset = State(initialValue: account?.remindBeforeReset ?? true)
        _alertNearLimit = State(initialValue: account?.alertNearLimit ?? true)
    }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    providerPreview
                } header: {
                    Text("Provider")
                } footer: {
                    Text("Choose the service this account belongs to. You can change it later.")
                }

                Section("Account Details") {
                    Picker("Provider", selection: $provider) {
                        ForEach(AgentProvider.allCases) { provider in
                            Label(provider.displayName, systemImage: provider.systemImage).tag(provider)
                        }
                    }
                    TextField("Nickname", text: $nickname)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .textInputAutocapitalization(.words)
                    #endif
                    #if os(iOS)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #else
                    TextField("Email", text: $email)
                    #endif
                    TextField("Plan tier", text: $planTier)
                }

                Section {
                    if limits.isEmpty {
                        ContentUnavailableView {
                            Label("No usage limits yet", systemImage: "chart.line.uptrend.xyaxis")
                        } description: {
                            Text("Add a session, daily, weekly, or monthly window to track cap usage on this account.")
                        }
                    }

                    ForEach($limits) { $limit in
                        LimitEditorRow(limit: $limit) {
                            limits.removeAll { $0.id == limit.id }
                        }
                    }

                    Button {
                        limits.append(UsageLimit(window: .weekly, usedPercent: 0))
                    } label: {
                        Label("Add Usage Limit", systemImage: "plus")
                    }
                } header: {
                    Text("Usage Limits")
                } footer: {
                    Text("Track the windows that matter most to this account. You can add more than one.")
                }

                Section {
                    Toggle("Remind before reset", isOn: $remindBeforeReset)
                    Toggle("Alert when nearing limit", isOn: $alertNearLimit)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Reminders are local to this device and never leave your account.")
                }

                Section {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Use notes for workspace details, model plan context, or anything else you want to remember later.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Account" : "Add Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        let saved = AgentAccount(
                            id: account?.id ?? UUID(),
                            provider: provider,
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            planTier: planTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : planTier.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                            limits: limits,
                            remindBeforeReset: remindBeforeReset,
                            alertNearLimit: alertNearLimit,
                            createdAt: account?.createdAt ?? .now
                        )
                        Task {
                            await onSave(saved)
                            dismiss()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 480, minHeight: 580)
        #endif
    }

    private var providerPreview: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: provider.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(provider.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 42, height: 42)
                .background(provider.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(provider.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.primary)
                Text(provider.vendorName)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct LimitEditorRow: View {
    @Binding var limit: UsageLimit
    let onDelete: () -> Void

    @State private var hasResetDate: Bool

    init(limit: Binding<UsageLimit>, onDelete: @escaping () -> Void) {
        self._limit = limit
        self.onDelete = onDelete
        _hasResetDate = State(initialValue: limit.wrappedValue.resetsAt != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Picker("Window", selection: $limit.window) {
                    ForEach(LimitWindow.allCases) { window in
                        Text(window.displayName).tag(window)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Usage").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(limit.usedPercent.rounded()))%").monospacedDigit()
                }
                Slider(value: $limit.usedPercent, in: 0...100, step: 1)
            }

            Toggle("Has a reset time", isOn: $hasResetDate)
                .onChange(of: hasResetDate) { _, newValue in
                    limit.resetsAt = newValue ? (limit.resetsAt ?? Date().addingTimeInterval(86400)) : nil
                }

            if hasResetDate {
                DatePicker(
                    "Resets at",
                    selection: Binding(
                        get: { limit.resetsAt ?? .now },
                        set: { limit.resetsAt = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            TextField("Label override", text: Binding(
                get: { limit.label ?? "" },
                set: { limit.label = $0.isEmpty ? nil : $0 }
            ))
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
