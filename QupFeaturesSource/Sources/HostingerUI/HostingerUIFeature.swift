import DesignSystem
import FeatureContracts
import Foundation
import Networking
import SwiftUI

// MARK: - HostingerUI Feature Module

public struct HostingerUIFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.hostinger")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.hostinger.route.dashboard"),
            featureID: Self.featureID,
            title: "hPanel",
            systemImage: "globe",
            group: "Features",
            order: 85,
            access: .init(requiresSignIn: true, allowedRoles: ["admin"], deniedPresentation: .locked)
        ) { context in
            AnyView(HostingerUIView(client: context.qlineClient))
        })
    }
}

// MARK: - Main HostingerUI View

/// Hostinger hPanel — DNS zone management, domain portfolio, hosting accounts.
///
/// Ported from `q-hpc-panel/src/routes/hpanel/`:
/// - Layout + credential picker: `+layout.svelte`
/// - DNS: `dns/+page.svelte`
/// - Domains: `domains/+page.svelte`
/// - Hosting: `hosting/+page.svelte`
public struct HostingerUIView: View {
    @StateObject private var state: HostingerUIState
    @State private var selectedTab: HostingerTab = .dns
    @Environment(\.cupertinoColors) private var colors

    public init(client: APIClient) {
        _state = StateObject(wrappedValue: HostingerUIState(client: client))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            credentialPicker
            tabStrip
            flashBanner
            detail
        }
        .background(colors.bg)
        .navigationTitle("hPanel")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await state.loadCredentials() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.title3)
                .foregroundStyle(colors.primary)
                .frame(width: 32, height: 32)
                .background(colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("Hostinger hPanel")
                    .font(.title2.weight(.bold))
                Text("Manage DNS zones, domain portfolio, and hosting accounts via Hostinger API.")
                    .font(.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer()
            Link(destination: URL(string: "https://hpanel.hostinger.com")!) {
                Label("Open hPanel", systemImage: "arrow.up.forward")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colors.surface, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(colors.fg)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Credential Picker

    private var credentialPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.caption)
                .foregroundStyle(colors.primary)
            Text("Active credential")
                .font(.caption.weight(.medium))
            Text("— Hostinger API token used for all requests")
                .font(.caption)
                .foregroundStyle(colors.mutedFg)
            Spacer()
            if state.credentialsLoaded {
                if !state.credentials.isEmpty {
                    Picker("Credential", selection: Binding(
                        get: { state.client.credentialID ?? -1 },
                        set: { state.setCredential($0 == -1 ? nil : $0) }
                    )) {
                        Text("Default credential").tag(-1)
                        ForEach(state.credentials) { cred in
                            Text(cred.label + (cred.isDefault ? " (default)" : "")).tag(cred.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(colors.primary)
                } else {
                    Text("Add a Hostinger API token in Settings")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(colors.primary)
                }
            } else {
                Text("Loading credentials…")
                    .font(.caption)
                    .foregroundStyle(colors.mutedFg)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(colors.border, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(HostingerTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                selectedTab == tab ? colors.card : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                selectedTab == tab
                                    ? RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1)
                                    : nil
                            )
                            .foregroundStyle(selectedTab == tab ? colors.primary : colors.mutedFg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 6)
        }
        .background(colors.surface)
    }

    // MARK: - Flash Banner

    @ViewBuilder
    private var flashBanner: some View {
        if let error = state.error {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text(error)
                    .font(.caption)
                Spacer()
                Button { state.clearMessages() } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(colors.danger)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(colors.danger.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 4)
        } else if let ok = state.ok {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(ok)
                    .font(.caption)
                Spacer()
                Button { state.clearMessages() } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(colors.success)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colors.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(colors.success.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .dns:
            DNSView(state: state)
        case .domains:
            DomainsView(state: state)
        case .hosting:
            HostingView(state: state)
        }
    }
}

// MARK: - Tab Enum

enum HostingerTab: String, CaseIterable, Identifiable {
    case dns, domains, hosting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dns: "DNS"
        case .domains: "Domains"
        case .hosting: "Hosting"
        }
    }

    var systemImage: String {
        switch self {
        case .dns: "cylinder.split"
        case .domains: "globe"
        case .hosting: "server.rack"
        }
    }
}

