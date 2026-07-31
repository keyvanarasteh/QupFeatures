import SwiftUI
import DesignSystem
import WikiAPI

// MARK: - Visibility Badge

public struct WikiVisibilityBadge: View {
    @Environment(\.cupertinoColors) private var colors
    let visibility: WikiVisibility

    public init(_ visibility: WikiVisibility) {
        self.visibility = visibility
    }

    public var body: some View {
        StatusBadge(visibility.displayName, tone: visibility.tone)
    }
}

extension WikiVisibility {
    var displayName: String {
        switch self {
        case .public: "Public"
        case .private: "Private"
        case .restricted: "Restricted"
        @unknown default: "Unknown"
        }
    }

    var tone: StatusTone {
        switch self {
        case .public: .info
        case .private: .danger
        case .restricted: .warning
        @unknown default: .neutral
        }
    }
}

// MARK: - Status Badge

public struct WikiStatusBadge: View {
    let status: WikiStatus

    public init(_ status: WikiStatus) {
        self.status = status
    }

    public var body: some View {
        StatusBadge(status.displayName, tone: status.tone)
    }
}

extension WikiStatus {
    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .published: "Published"
        case .archived: "Archived"
        @unknown default: "Unknown"
        }
    }

    var tone: StatusTone {
        switch self {
        case .draft: .neutral
        case .published: .info
        case .archived: .warning
        @unknown default: .neutral
        }
    }
}

// MARK: - Tag Chip

public struct WikiTagChip: View {
    @Environment(\.cupertinoColors) private var colors
    let tag: String
    var removable: Bool
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    public init(
        _ tag: String,
        removable: Bool = false,
        onTap: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.tag = tag
        self.removable = removable
        self.onTap = onTap
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(tag)
                .font(Theme.Typography.captionEmphasized)
            if removable {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Remove tag")
            }
        }
        .foregroundStyle(colors.primary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(colors.primarySoft, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(colors.primary.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Capsule())
        .onTapGesture { onTap?() }
        .accessibilityLabel(tag)
        .accessibilityAddTraits(removable ? .isButton : [])
    }
}
