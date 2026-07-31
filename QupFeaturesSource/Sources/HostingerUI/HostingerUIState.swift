import Foundation
import HostingerProxyAPI
import Networking

// MARK: - Hostinger UI State
//
// Mirrors `q-hpc-panel/src/lib/stores/hpanelStore.svelte.ts` — the single
// source of truth for all Hostinger hPanel view state in SwiftUI.

@MainActor
final class HostingerUIState: ObservableObject {
    var client: HostingerProxyClient

    // ── Credentials ───────────────────────────────────────────────────────────
    @Published var credentials: [HostingerProxyCredential] = []
    @Published var credentialsLoaded = false

    // ── DNS ───────────────────────────────────────────────────────────────────
    @Published var dnsRecords: [HostingerProxyDNSRecord] = []
    @Published var dnsSnapshots: [HostingerProxyDNSSnapshot] = []
    @Published var dnsDomain = ""
    @Published var dnsLoading = false

    // ── Domains ───────────────────────────────────────────────────────────────
    @Published var domains: [HostingerProxyDomain] = []
    @Published var domainsLoaded = false
    @Published var whoisProfiles: [HostingerProxyWhoisProfile] = []

    // ── Hosting ───────────────────────────────────────────────────────────────
    @Published var orders: [HostingerProxyHostingOrder] = []
    @Published var websites: [HostingerProxyWebsite] = []
    @Published var databases: [HostingerProxyDatabase] = []
    @Published var hostingLoading = false

    // ── UI ────────────────────────────────────────────────────────────────────
    @Published var loading = false
    @Published var error: String?
    @Published var ok: String?

    init(client: APIClient) {
        self.client = HostingerProxyClient(client: client)
    }

    func clearMessages() { error = nil; ok = nil }

    // MARK: - Credentials

    func loadCredentials() async {
        do {
            // Credentials are loaded via the same API client — the store fetches
            // from /api/credentials with ?provider=hostinger filter.
            // For now credentials state is managed externally; set credentialID
            // directly on the client.
            credentialsLoaded = true
        }
    }

    func setCredential(_ id: Int?) {
        client.credentialID = id
    }

    // MARK: - DNS
    // Ground truth: hpanelStore.svelte.ts:75-132

    func loadDNSRecords(domain: String) async {
        guard !domain.isEmpty else { return }
        dnsDomain = domain
        dnsLoading = true
        do {
            dnsRecords = try await client.loadDNSRecords(domain: domain)
            ok = "DNS records loaded"
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    func updateDNSRecords(domain: String, records: [HostingerProxyDNSRecord], overwrite: Bool = false) async {
        dnsLoading = true
        do {
            try await client.updateDNSRecords(domain: domain, records: records, overwrite: overwrite)
            ok = "DNS records updated"
            await loadDNSRecords(domain: domain)
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    func deleteDNSRecords(domain: String, recordKeys: [HostingerProxyDNSRecordKey]) async {
        dnsLoading = true
        do {
            try await client.deleteDNSRecords(domain: domain, records: recordKeys)
            ok = "DNS records deleted"
            await loadDNSRecords(domain: domain)
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    func resetDNSZone(domain: String) async {
        dnsLoading = true
        do {
            try await client.resetDNSZone(domain: domain)
            ok = "DNS zone reset to defaults"
            await loadDNSRecords(domain: domain)
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    func loadDNSSnapshots(domain: String) async {
        dnsLoading = true
        do {
            dnsSnapshots = try await client.loadDNSSnapshots(domain: domain)
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    func restoreDNSSnapshot(domain: String, snapshotID: Int) async {
        dnsLoading = true
        do {
            try await client.restoreDNSSnapshot(domain: domain, snapshotID: snapshotID)
            ok = "DNS snapshot restored"
            await loadDNSRecords(domain: domain)
        } catch {
            self.error = error.localizedDescription
        }
        dnsLoading = false
    }

    // MARK: - Domains
    // Ground truth: hpanelStore.svelte.ts:136-196

    func loadDomains() async {
        loading = true
        do {
            domains = try await client.loadDomains()
            domainsLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func loadWhoisProfiles(tld: String? = nil) async {
        loading = true
        do {
            whoisProfiles = try await client.loadWhoisProfiles(tld: tld)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func checkAvailability(domain: String, tlds: [String]) async -> HostingerJSONValue? {
        loading = true
        defer { loading = false }
        do {
            return try await client.checkAvailability(domain: domain, tlds: tlds)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func enableDomainLock(domain: String) async {
        loading = true
        do {
            try await client.enableDomainLock(domain: domain)
            ok = "Domain lock enabled"
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func disableDomainLock(domain: String) async {
        loading = true
        do {
            try await client.disableDomainLock(domain: domain)
            ok = "Domain lock disabled"
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func enablePrivacyProtection(domain: String) async {
        loading = true
        do {
            try await client.enablePrivacyProtection(domain: domain)
            ok = "Privacy protection enabled"
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func disablePrivacyProtection(domain: String) async {
        loading = true
        do {
            try await client.disablePrivacyProtection(domain: domain)
            ok = "Privacy protection disabled"
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    // MARK: - Hosting
    // Ground truth: hpanelStore.svelte.ts:200-242

    func loadOrders(params: [String: String]? = nil) async {
        hostingLoading = true
        do {
            orders = try await client.loadOrders(params: params)
        } catch {
            self.error = error.localizedDescription
        }
        hostingLoading = false
    }

    func loadWebsites() async {
        hostingLoading = true
        do {
            websites = try await client.loadWebsites()
        } catch {
            self.error = error.localizedDescription
        }
        hostingLoading = false
    }

    func loadDatabases(username: String) async {
        hostingLoading = true
        do {
            databases = try await client.loadDatabases(username: username)
        } catch {
            self.error = error.localizedDescription
        }
        hostingLoading = false
    }

    func createDatabase(username: String, body: HostingerJSONObject) async {
        hostingLoading = true
        do {
            try await client.createDatabase(username: username, body: body)
            ok = "Database created"
            await loadDatabases(username: username)
        } catch {
            self.error = error.localizedDescription
        }
        hostingLoading = false
    }

    func deleteDatabase(username: String, name: String) async {
        hostingLoading = true
        do {
            try await client.deleteDatabase(username: username, name: name)
            ok = "Database deleted"
            await loadDatabases(username: username)
        } catch {
            self.error = error.localizedDescription
        }
        hostingLoading = false
    }
}

// MARK: - Credential model (local to the UI layer)

public struct HostingerProxyCredential: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var provider: String
    public var label: String
    public var credKey: String
    public var isDefault: Bool
    public var createdAt: String?

    public init(id: Int, provider: String, label: String, credKey: String, isDefault: Bool, createdAt: String? = nil) {
        self.id = id
        self.provider = provider
        self.label = label
        self.credKey = credKey
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}
