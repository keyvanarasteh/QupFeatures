import SwiftUI
import DesignSystem
import WikiAPI

/// Home › Section › Article path navigation.
public struct WikiBreadcrumbView: View {
    let items: [BreadcrumbItem]

    public struct BreadcrumbItem: Identifiable {
        public let id: String
        public let label: String
        public let href: String?

        public init(label: String, href: String? = nil) {
            self.id = UUID().uuidString
            self.label = label
            self.href = href
        }
    }

    public init(items: [BreadcrumbItem]) {
        self.items = items
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    if let href = item.href {
                        Button {
                            // Navigation handled by parent via href
                        } label: {
                            Text(item.label)
                                .font(Theme.Typography.captionEmphasized)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(href)
                    } else {
                        Text(item.label)
                            .font(Theme.Typography.captionEmphasized)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Breadcrumb")
    }
}
