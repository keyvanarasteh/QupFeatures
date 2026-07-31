import DesignSystem
import HostingerProxyAPI
import SwiftUI

// MARK: - DNS View
//
// Ported from `q-hpc-panel/src/routes/hpanel/dns/+page.svelte`.
// Domain search, records table, add-record form, snapshot management.

struct DNSView: View {
    @ObservedObject var state: HostingerUIState
    @Environment(\.cupertinoColors) private var colors

    @State private var domainInput = ""
    @State private var showSnapshots = false

    // New record form
    @State private var newName = ""
    @State private var newType = "A"
    @State private var newValue = ""
    @State private var newTTL = 3600

    private let dnsTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "CAA", "PTR"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                domainSearchBar
                if !state.dnsDomain.isEmpty {
                    recordsSection
                    addRecordForm
                    if showSnapshots {
                        snapshotsSection
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(colors.bg)
    }

    // MARK: - Domain Search

    private var domainSearchBar: some View {
        CardView(padding: Theme.Spacing.lg, cornerRadius: Theme.Radius.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Domain".uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(colors.mutedFg)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    TextField("example.com", text: $domainInput)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.border, lineWidth: 1)
                        )
                        .onSubmit { fetchRecords() }

                    Button(action: fetchRecords) {
                        HStack(spacing: 6) {
                            if state.dnsLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .imageScale(.small)
                            }
                            Text("Load")
                                .font(.callout.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.dnsLoading)
                }
            }
        }
    }

    private func fetchRecords() {
        let d = domainInput.trimmingCharacters(in: .whitespaces)
        guard !d.isEmpty else { return }
        Task { await state.loadDNSRecords(domain: d) }
    }

    // MARK: - Records Table

    private var recordsSection: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "cylinder.split")
                        .font(.caption)
                        .foregroundStyle(colors.primary)
                    Text(state.dnsDomain)
                        .font(.callout.weight(.semibold))
                    Text("— \(state.dnsRecords.count) record(s)")
                        .font(.caption)
                        .foregroundStyle(colors.mutedFg)
                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { showSnapshots.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("Snapshots")
                                Image(systemName: showSnapshots ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colors.surface, in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(colors.mutedFg)
                        }
                        .buttonStyle(.plain)

                        Button(action: resetZone) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset zone")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(colors.danger)
                            .background(colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button(action: fetchRecords) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .padding(6)
                                .foregroundStyle(colors.mutedFg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 12)
                .overlay(Divider(), alignment: .bottom)

                if state.dnsRecords.isEmpty {
                    VStack(spacing: 4) {
                        Text("No records found.")
                            .font(.callout)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Table header
                    HStack(spacing: 0) {
                        Text("Name").font(.caption2.weight(.medium)).foregroundStyle(colors.mutedFg).frame(width: 140, alignment: .leading).padding(.leading, Theme.Spacing.lg).padding(.vertical, 8)
                        Text("Type").font(.caption2.weight(.medium)).foregroundStyle(colors.mutedFg).frame(width: 60, alignment: .leading).padding(.vertical, 8)
                        Text("Value").font(.caption2.weight(.medium)).foregroundStyle(colors.mutedFg).frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8).padding(.vertical, 8)
                        Text("TTL").font(.caption2.weight(.medium)).foregroundStyle(colors.mutedFg).frame(width: 50, alignment: .leading).padding(.vertical, 8)
                        Spacer().frame(width: 32)
                    }
                    .overlay(Divider(), alignment: .bottom)

                    ForEach(Array(state.dnsRecords.enumerated()), id: \.offset) { _, record in
                        HStack(spacing: 0) {
                            Text(record.name ?? "@")
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                                .padding(.leading, Theme.Spacing.lg)

                            Text(record.type ?? "")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(colors.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                                .frame(width: 60, alignment: .leading)

                            Text(record.displayValue)
                                .font(.caption.monospaced())
                                .foregroundStyle(colors.mutedFg)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 8)

                            Text(record.ttl.map { "\($0)" } ?? "—")
                                .font(.caption)
                                .foregroundStyle(colors.mutedFg)
                                .frame(width: 50, alignment: .leading)

                            Button(action: { deleteRecord(record) }) {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundStyle(colors.danger)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 32)
                        }
                        .padding(.vertical, 6)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
        }
    }

    private func deleteRecord(_ record: HostingerProxyDNSRecord) {
        guard let name = record.name, let type = record.type else { return }
        Task { await state.deleteDNSRecords(
            domain: state.dnsDomain,
            recordKeys: [HostingerProxyDNSRecordKey(name: name, type: type)]
        )}
    }

    private func resetZone() {
        Task { await state.resetDNSZone(domain: state.dnsDomain) }
    }

    // MARK: - Add Record Form

    private var addRecordForm: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                HStack {
                    Text("Add DNS Record")
                        .font(.callout.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 12)
                .overlay(Divider(), alignment: .bottom)

                VStack(spacing: 12) {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name").font(.caption2).foregroundStyle(colors.mutedFg)
                            TextField("@ or subdomain", text: $newName)
                                .textFieldStyle(.plain)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Type").font(.caption2).foregroundStyle(colors.mutedFg)
                            Picker("Type", selection: $newType) {
                                ForEach(dnsTypes, id: \.self) { t in
                                    Text(t).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Value").font(.caption2).foregroundStyle(colors.mutedFg)
                            TextField("IP or target", text: $newValue)
                                .textFieldStyle(.plain)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TTL (s)").font(.caption2).foregroundStyle(colors.mutedFg)
                            TextField("3600", value: $newTTL, format: .number)
                                .textFieldStyle(.plain)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colors.inputBg, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
                        }
                    }

                    Button(action: addRecord) {
                        Text("Add Record")
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.isEmpty || newValue.isEmpty || state.dnsLoading)
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }

    private func addRecord() {
        guard !newName.isEmpty, !newValue.isEmpty else { return }
        let record = HostingerProxyDNSRecord(name: newName, type: newType, value: newValue, ttl: newTTL)
        Task { await state.updateDNSRecords(domain: state.dnsDomain, records: [record]) }
        newName = ""
        newValue = ""
    }

    // MARK: - Snapshots

    private var snapshotsSection: some View {
        CardView(padding: 0, cornerRadius: Theme.Radius.lg) {
            VStack(spacing: 0) {
                HStack {
                    Text("DNS Snapshots")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Button(action: { Task { await state.loadDNSSnapshots(domain: state.dnsDomain) } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .padding(6)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 12)
                .overlay(Divider(), alignment: .bottom)

                if state.dnsSnapshots.isEmpty {
                    VStack(spacing: 4) {
                        Text("No snapshots available.")
                            .font(.callout)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(state.dnsSnapshots, id: \.id) { snap in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Snapshot #\(snap.id)")
                                    .font(.callout.weight(.medium))
                                if let createdAt = snap.createdAt {
                                    Text(createdAt)
                                        .font(.caption)
                                        .foregroundStyle(colors.mutedFg)
                                }
                            }
                            Spacer()
                            Button(action: { Task { await state.restoreDNSSnapshot(domain: state.dnsDomain, snapshotID: snap.id) } }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Restore")
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(colors.primary)
                                .background(colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 10)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - DNS Record Helpers

extension HostingerProxyDNSRecord {
    var displayValue: String {
        value ?? ""
    }
}
