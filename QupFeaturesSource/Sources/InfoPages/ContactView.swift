import SwiftUI
import DesignSystem
import ComponentSystem
import DynamicUI
import QlineAuth

/// Contact page — UX only (no network submit). Ported verbatim from 11Q's
/// `Features/Contact/ContactView.swift` (`AuthValidation` now comes from QlineAuth).
/// Tips card is a **DynamicUI host** so orgs can customize help text without a ship.
public struct ContactView: View {
    @Environment(\.eqColors) private var colors
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var name = ""
    @State private var email = ""
    @State private var topic: ContactTopic = .general
    @State private var message = ""
    @State private var preferEmail = true
    @State private var preferChat = false
    @State private var showValidation = false
    @State private var submitted = false

    public init() {}

    private var canSubmit: Bool {
        AuthValidation.trimmedNonEmpty(name) != nil
            && AuthValidation.looksLikeEmail(email)
            && AuthValidation.trimmedNonEmpty(message) != nil
            && message.count >= 10
    }

    public var body: some View {
        EQPageContainer {
            VStack(alignment: .leading, spacing: EQSpacing.xxl) {
                EQSectionHeader(
                    title: "Contact",
                    subtitle: "Tell us how we can help. This form is UX-only for now — nothing is sent yet.",
                    systemImage: "envelope.open.fill"
                )

                if submitted {
                    successCard
                } else {
                    formCard
                    tipsCard
                }
            }
        }
        .navigationTitle("Contact")
        #if os(iOS)
        .navigationBarTitleDisplayMode(sizeClass == .compact ? .large : .inline)
        #endif
    }

    private var formCard: some View {
        EQCard(padding: EQSpacing.xxl) {
            VStack(alignment: .leading, spacing: EQSpacing.lg) {
                EQAdaptiveStack(spacing: EQSpacing.lg) {
                    fieldBlock(label: "Name", error: showValidation && AuthValidation.trimmedNonEmpty(name) == nil ? "Required" : nil) {
                        TextField("Your name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textContentType(.name)
                            #endif
                    }
                    fieldBlock(
                        label: "Email",
                        error: showValidation && !AuthValidation.looksLikeEmail(email) ? "Enter a valid email" : nil
                    ) {
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Topic")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(colors.fg)
                    Picker("Topic", selection: $topic) {
                        ForEach(ContactTopic.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Message")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(colors.fg)
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(colors.inputBg, in: RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                                .stroke(colors.border, lineWidth: 1)
                        )
                    if showValidation && message.count < 10 {
                        Text("Please write at least 10 characters")
                            .font(.caption)
                            .foregroundStyle(colors.danger)
                    }
                }

                VStack(alignment: .leading, spacing: EQSpacing.sm) {
                    Text("Preferred reply")
                        .font(.subheadline.weight(.medium))
                    Toggle("Email", isOn: $preferEmail)
                    Toggle("In-app chat (coming soon)", isOn: $preferChat)
                }
                .tint(colors.primary)

                EQAdaptiveStack(spacing: EQSpacing.md) {
                    EQPrimaryButton("Send message", systemImage: "paperplane.fill", expands: true) {
                        showValidation = true
                        guard canSubmit else { return }
                        withAnimation(.snappy) {
                            submitted = true
                        }
                    }
                    EQSecondaryButton("Clear", systemImage: "xmark", expands: true) {
                        resetForm()
                    }
                }
            }
        }
    }

    private var successCard: some View {
        EQCard(padding: EQSpacing.xxxl) {
            VStack(spacing: EQSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(colors.success)
                    .symbolRenderingMode(.hierarchical)
                Text("Message ready")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colors.fg)
                Text("Thanks, \(name). This is a UI preview — wiring to a backend can come next.")
                    .font(.subheadline)
                    .foregroundStyle(colors.mutedFg)
                    .multilineTextAlignment(.center)
                EQPrimaryButton("Write another", systemImage: "square.and.pencil") {
                    withAnimation(.snappy) {
                        resetForm()
                        submitted = false
                    }
                }
                .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var tipsCard: some View {
        DynamicHostView(
            json: ContactTipsDynamicFixture.json,
            embedStyle: .plain,
            installExtensions: InfoDynamicHost.installExtensions
        )
        .frame(minHeight: 160)
    }

    private func fieldBlock<Content: View>(
        label: String,
        error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colors.fg)
            content()
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(colors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetForm() {
        name = ""
        email = ""
        topic = .general
        message = ""
        preferEmail = true
        preferChat = false
        showValidation = false
    }
}

enum ContactTopic: String, CaseIterable, Identifiable {
    case general
    case support
    case feedback
    case billing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .support: return "Support"
        case .feedback: return "Feedback"
        case .billing: return "Billing"
        }
    }
}
