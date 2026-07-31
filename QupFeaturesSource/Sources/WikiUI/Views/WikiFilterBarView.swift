import SwiftUI
import DesignSystem
import WikiAPI

/// Search + tags + status + visibility + sort filter bar.
public struct WikiFilterBarView: View {
    @Environment(\.cupertinoColors) private var colors

    @Binding var query: String
    @Binding var tags: [String]
    @Binding var sectionId: Int?
    @Binding var status: WikiStatus?
    @Binding var visibility: WikiVisibility?
    @Binding var sort: String
    @Binding var order: String

    var sections: [WikiSection]
    var showStatus: Bool
    var showVisibility: Bool
    var onChange: (() -> Void)?

    @State private var tagInput = ""
    @State private var showFilters = false
    @State private var debounceTask: Task<Void, Never>?

    private let debounceInterval: Duration = .milliseconds(300)

    public init(
        query: Binding<String>,
        tags: Binding<[String]> = .constant([]),
        sectionId: Binding<Int?> = .constant(nil),
        status: Binding<WikiStatus?> = .constant(nil),
        visibility: Binding<WikiVisibility?> = .constant(nil),
        sort: Binding<String> = .constant("relevance"),
        order: Binding<String> = .constant("desc"),
        sections: [WikiSection] = [],
        showStatus: Bool = true,
        showVisibility: Bool = true,
        onChange: (() -> Void)? = nil
    ) {
        _query = query
        _tags = tags
        _sectionId = sectionId
        _status = status
        _visibility = visibility
        _sort = sort
        _order = order
        self.sections = sections
        self.showStatus = showStatus
        self.showVisibility = showVisibility
        self.onChange = onChange
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Search row
            HStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search articles…", text: $query)
                        .font(Theme.Typography.subheadline)
                        .textFieldStyle(.plain)
                        .onChange(of: query) { _, _ in
                            debounceTask?.cancel()
                            debounceTask = Task {
                                try? await Task.sleep(for: debounceInterval)
                                onChange?()
                            }
                        }
                    if !query.isEmpty {
                        Button { query = ""; onChange?() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(colors.inputBg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(colors.border, lineWidth: 1)
                )

                // Tag chip input
                HStack(spacing: 2) {
                    ForEach(tags, id: \.self) { tag in
                        WikiTagChip(tag, removable: true) {
                            tags.removeAll { $0 == tag }
                            onChange?()
                        }
                    }
                    TextField("Tags…", text: $tagInput)
                        .font(Theme.Typography.caption)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 120)
                        .onSubmit { commitTag() }
                        .onChange(of: tagInput) { _, new in
                            if new.hasSuffix(",") || new.hasSuffix(" ") {
                                tagInput = new.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                                commitTag()
                            }
                        }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(colors.inputBg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(colors.border, lineWidth: 1)
                )

                // Filter toggle button (compact)
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Button { showFilters.toggle() } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.caption)
                    }
                    .buttonStyle(.secondary)
                    .help("Filters")
                }
                #endif
            }

            // Filter row (always visible on mac/tablet, sheet on phone)
            let filters = filterContent
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                if showFilters {
                    filters
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                filters
            }
            #else
            filters
            #endif
        }
        .animation(.snappy, value: showFilters)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Article filters")
    }

    @ViewBuilder
    private var filterContent: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Section picker
            if !sections.isEmpty {
                Picker("Section", selection: Binding(
                    get: { sectionId ?? -1 },
                    set: { sectionId = $0 == -1 ? nil : $0; onChange?() }
                )) {
                    Text("All sections").tag(-1)
                    ForEach(sections) { sec in
                        Text(sec.title).tag(sec.id)
                    }
                }
                .pickerStyle(.menu)
                .font(Theme.Typography.caption)
                .frame(maxWidth: 160)
            }

            // Status filter
            if showStatus {
                Picker("Status", selection: Binding(
                    get: { status?.rawValue ?? "" },
                    set: { status = $0.isEmpty ? nil : WikiStatus(rawValue: $0); onChange?() }
                )) {
                    Text("Any status").tag("")
                    ForEach(WikiStatus.allDisplayCases, id: \.rawValue) { s in
                        Text(s.displayName).tag(s.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .font(Theme.Typography.caption)
            }

            // Visibility filter
            if showVisibility {
                Picker("Visibility", selection: Binding(
                    get: { visibility?.rawValue ?? "" },
                    set: { visibility = $0.isEmpty ? nil : WikiVisibility(rawValue: $0); onChange?() }
                )) {
                    Text("Any visibility").tag("")
                    ForEach(WikiVisibility.allDisplayCases, id: \.rawValue) { v in
                        Text(v.displayName).tag(v.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .font(Theme.Typography.caption)
            }

            // Sort
            Picker("Sort", selection: $sort) {
                Text("Relevance").tag("relevance")
                Text("Title").tag("title")
                Text("Views").tag("view_count")
                Text("Created").tag("created_at")
                Text("Updated").tag("updated_at")
            }
            .pickerStyle(.menu)
            .font(Theme.Typography.caption)
            .onChange(of: sort) { _, _ in onChange?() }

            // Order
            Picker("Order", selection: $order) {
                Image(systemName: "arrow.down").tag("desc")
                Image(systemName: "arrow.up").tag("asc")
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
            .onChange(of: order) { _, _ in onChange?() }

            // Clear all
            if hasActiveFilters {
                Button("Clear") {
                    query = ""
                    tags = []
                    sectionId = nil
                    status = nil
                    visibility = nil
                    sort = "relevance"
                    order = "desc"
                    onChange?()
                }
                .buttonStyle(.ghost)
                .font(Theme.Typography.caption)
            }

            Spacer()
        }
    }

    private var hasActiveFilters: Bool {
        !query.isEmpty || !tags.isEmpty || sectionId != nil || status != nil || visibility != nil
            || sort != "relevance" || order != "desc"
    }

    private func commitTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(trimmed) {
            tags.append(trimmed)
            onChange?()
        }
        tagInput = ""
    }
}

extension WikiStatus {
    static var allDisplayCases: [WikiStatus] { [.draft, .published, .archived] }
}
extension WikiVisibility {
    static var allDisplayCases: [WikiVisibility] { [.public, .private, .restricted] }
}
