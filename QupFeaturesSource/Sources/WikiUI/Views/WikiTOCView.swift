import SwiftUI
import DesignSystem

/// Sticky table of contents extracted from article headings (h2/h3).
public struct WikiTOCView: View {
    @Environment(\.cupertinoColors) private var colors
    let headings: [TOCHeading]
    let activeId: String?
    let onTap: (String) -> Void

    @State private var collapsed = false

    public struct TOCHeading: Identifiable {
        public let id: String
        public let text: String
        public let level: Int // 2 or 3

        public init(id: String, text: String, level: Int) {
            self.id = id
            self.text = text
            self.level = level
        }
    }

    public init(
        headings: [TOCHeading],
        activeId: String? = nil,
        onTap: @escaping (String) -> Void = { _ in }
    ) {
        self.headings = headings
        self.activeId = activeId
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                withAnimation(.snappy) { collapsed.toggle() }
            } label: {
                HStack {
                    Text("On this page")
                        .font(Theme.Typography.captionEmphasized)
                        .foregroundStyle(colors.fg)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(collapsed ? -90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !collapsed {
                ForEach(headings) { heading in
                    Button {
                        onTap(heading.id)
                    } label: {
                        Text(heading.text)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(
                                activeId == heading.id ? colors.primary : .secondary
                            )
                            .lineLimit(2)
                            .padding(.leading, heading.level == 3 ? Theme.Spacing.md : 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .frame(maxWidth: 240)
        .sticky()
        .animation(.snappy, value: collapsed)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table of contents")
    }
}

/// Sticky positioning modifier — pins the view to the top on scroll.
private struct StickyModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .containerRelativeFrame(.vertical, alignment: .top) { height, _ in height }
        } else {
            content
        }
    }
}

extension View {
    fileprivate func sticky() -> some View {
        modifier(StickyModifier())
    }
}
