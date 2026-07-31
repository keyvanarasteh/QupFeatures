import SwiftUI
import DesignSystem
import WikiAPI

/// Pagination controls: prev · page numbers · next with total count.
public struct WikiPaginationView: View {
    @Environment(\.cupertinoColors) private var colors
    let page: Int
    let pages: Int
    let total: Int
    let onPage: (Int) -> Void

    public init(page: Int, pages: Int, total: Int, onPage: @escaping (Int) -> Void) {
        self.page = page
        self.pages = pages
        self.total = total
        self.onPage = onPage
    }

    public var body: some View {
        HStack {
            // Page info
            Text("\(startItem)–\(endItem) of \(total)")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 2) {
                // Previous
                Button {
                    onPage(page - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(page > 1 ? colors.fg : colors.mutedFg)
                .disabled(page <= 1)
                .frame(width: 32, height: 28)
                .help("Previous page")

                // Page numbers
                ForEach(visiblePages, id: \.self) { p in
                    if p == -1 {
                        Text("…")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                    } else {
                        Button {
                            onPage(p)
                        } label: {
                            Text("\(p)")
                                .font(Theme.Typography.captionEmphasized)
                                .frame(width: 28, height: 28)
                                .background(
                                    p == page
                                        ? colors.primarySoft
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                                )
                                .foregroundStyle(p == page ? colors.primary : colors.mutedFg)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Next
                Button {
                    onPage(page + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(page < pages ? colors.fg : colors.mutedFg)
                .disabled(page >= pages)
                .frame(width: 32, height: 28)
                .help("Next page")
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pagination, page \(page) of \(pages)")
    }

    private var startItem: Int { (page - 1) * 50 + 1 }
    private var endItem: Int { min(page * 50, total) }

    private var visiblePages: [Int] {
        guard pages > 1 else { return [] }
        if pages <= 7 {
            return Array(1...pages)
        }
        var result: [Int] = []
        result.append(1)
        if page > 3 { result.append(-1) }
        let start = max(2, page - 1)
        let end = min(pages - 1, page + 1)
        for i in start...end { result.append(i) }
        if page < pages - 2 { result.append(-1) }
        result.append(pages)
        return result
    }
}
