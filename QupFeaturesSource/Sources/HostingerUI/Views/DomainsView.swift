import DesignSystem
import HostingerProxyAPI
import SwiftUI

// MARK: - Domains View
//
// Ported from `q-hpc-panel/src/routes/hpanel/domains/+page.svelte`.
// Domain availability checker, portfolio list, lock/privacy toggles, WHOIS.

struct DomainsView: View {
    @ObservedObject var state: HostingerUIState
    @Environment(\.cupertinoColors) private var colors

    @State private var avDomain = ""
    @State private var avTlds = "com net org"
    @State private var avResult: HostingerJSONValue?
    @State private var showWhois = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                availabilityChecker
                domainPortfolio
                whoisSection
            }
            .padding(Theme.Spacing.lg)
        }
        .background(colors.bg)
        .task { await state.loadDomains() }
    }

    // MARK: - Availability Checker

    private var availabilityChecker: some View {
        CardView(padding: Theme.Spacing.lg, cornerRadius: Theme.Radius.lg) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(colors.primary)
                    Text("Check Availability")
                        .font(.callout.weight(.semibold))
                }

                HStack(spacing: 8) {
                    TextField("mydomain", text: $avDomain)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))

                    TextField("com net org", text: $avTlds)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .frame(width: 120)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))

                    Button(action: checkAvailability) {
                        HStack(spacing: 6) {
                            if state.loading {
                                ProgressView().scaleEffect(0.7).tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass").imageScale(.small)
                            }
                            Text("Check")
                                .font(.callout.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.loading || avDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if case let .object(dict) = avResult {
                    availabilityResults(dict)
                } else if case let .array(items) = avResult {
                    availabilityList(items)
                }
            }
        }
    }

    @ViewBuilder
    private func availabilityResults(_ dict: [String: HostingerJSONValue]) -> some View {
        if case let .array(items) = dict["data"] {
            availabilityList(items)
        } else {
            availabilitySingleResult(dict)
        }
    }

    private func availabilitySingleResult(_ dict: [String: HostingerJSONValue]) -> some View {
        guard case let .string(domain) = dict["domain"] else {
            return AnyView(EmptyView())
        }
        let isAvail: Bool = {
            if case let .bool(b) = dict["available"] ?? dict["is_available"] { return b }
            return false
        }()
        return AnyView(
            LazyVGrid(columns: [.init(.flexible())], spacing: 8) {
                HStack {
                    Text(domain).font(.caption.monospaced())
                    Spacer()
                    if isAvail {
                        Text("Available")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(colors.success)
                    } else {
                        Text("Taken")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(colors.mutedFg)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isAvail ? colors.success.opacity(0.05) : colors.surface, in: RoundedRectangle(cornerRadius: 8))
            }
        )
    }

    private func availabilityList(_ items: [HostingerJSONValue]) -> some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if case let .object(dict) = item {
                    let domain: String = {
                        if case let .string(d) = dict["domain"] { return d }
                        return ""
                    }()
                    let available: Bool = {
                        if case let .bool(b) = dict["available"] ?? dict["is_available"] { return b }
                        return false
                    }()
                    HStack {
                        Text(domain).font(.caption.monospaced()).lineLimit(1)
                        Spacer()
                        Text(available ? "Available" : "Taken")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(available ? colors.success : colors.mutedFg)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(available ? colors.success.opacity(0.05) : colors.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func checkAvailability() {
        let domain = avDomain.trimmingCharacters(in: .whitespaces)
        let tlds = avTlds.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: CharacterSet.whitespaces.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
        guard !domain.isEmpty, !tlds.isEmpty else { return }
        Task {
            avResult = await state.checkAvailability(domain: domain, tlds: tlds)
        }
    }

    // MARK: - Domain Portfolio

    private var domainPortfolio: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(colors.primary)
                    Text("Domain Portfolio")
                        .font(.callout.weight(.semibold))
                    Text("(\(state.domains.count))")
                        .font(.caption)
                        .foregroundStyle(colors.mutedFg)
                    Spacer()
                    Button(action: { Task { await state.loadDomains() } }) {
                        if state.loading && !state.domainsLoaded {
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

                if state.loading && !state.domainsLoaded {
                    HStack {
                        Spacer()
                        ProgressView().tint(colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, 48)
                } else if state.domains.isEmpty {
                    VStack(spacing: 4) {
                        Text("No domains found.")
                            .font(.callout)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(state.domains) { domain in
                        domainRow(domain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func domainRow(_ domain: HostingerProxyDomain) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(domain.domain)
                        .font(.callout.weight(.medium))
                    if let status = domain.status, !status.isEmpty {
                        Text(status)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colors.primary.opacity(0.1), in: Capsule())
                    }
                    if domain.isLocked == true {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.warning)
                    }
                    if domain.privacyProtection == true {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.success)
                    }
                }
                if let expires = domain.expiresAt {
                    Text("Expires: \(expires)")
                        .font(.caption)
                        .foregroundStyle(expireColor(expires))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if domain.isLocked == true {
                    actionButton("lock.open.fill", "Unlock", colors.warning) {
                        Task { await state.disableDomainLock(domain: domain.domain) }
                    }
                } else {
                    actionButton("lock.fill", "Lock", colors.mutedFg) {
                        Task { await state.enableDomainLock(domain: domain.domain) }
                    }
                }

                if domain.privacyProtection == true {
                    actionButton("shield.slash.fill", "Privacy off", colors.success) {
                        Task { await state.disablePrivacyProtection(domain: domain.domain) }
                    }
                } else {
                    actionButton("checkmark.shield.fill", "Privacy on", colors.mutedFg) {
                        Task { await state.enablePrivacyProtection(domain: domain.domain) }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }

    private func expireColor(_ dateStr: String) -> Color {
        // Simple heuristic: if the date string contains a past-ish value
        // would ideally parse ISO dates, but for UI purposes just show warning color
        colors.mutedFg
    }

    private func actionButton(_ systemImage: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption2)
                Text(label).font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - WHOIS Profiles

    private var whoisSection: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                Button(action: { showWhois.toggle() }) {
                    HStack {
                        Text("WHOIS Profiles")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Image(systemName: showWhois ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showWhois {
                    if state.whoisProfiles.isEmpty {
                        VStack(spacing: 4) {
                            Text("No WHOIS profiles found.")
                                .font(.callout)
                                .foregroundStyle(colors.mutedFg)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .overlay(Divider(), alignment: .top)
                    } else {
                        ForEach(state.whoisProfiles) { profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("#\(profile.id) \(profile.name ?? "")")
                                        .font(.callout.weight(.medium))
                                    if let email = profile.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(colors.mutedFg)
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
    }
}
