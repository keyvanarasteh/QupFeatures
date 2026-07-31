import SwiftUI
import Photos
import DesignSystem

public struct DownloadOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors
    
    let itemsCount: Int
    let thumbnailImage: Image?
    let onDownload: (PhotoDownloadOption) -> Void
    
    public init(itemsCount: Int, thumbnailImage: Image?, onDownload: @escaping (PhotoDownloadOption) -> Void) {
        self.itemsCount = itemsCount
        self.thumbnailImage = thumbnailImage
        self.onDownload = onDownload
    }

    private var formattedItemsCount: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: itemsCount)) ?? "\(itemsCount)"
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Theme.Spacing.sm) {
                        if let thumbnailImage = thumbnailImage {
                            thumbnailImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        } else {
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(colors.muted)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(.title3, design: .default, weight: .regular))
                                        .foregroundStyle(colors.mutedFg)
                                        .accessibilityHidden(true)
                                }
                        }
                        
                        Text("\(formattedItemsCount) Items")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(colors.mutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                
                Section {
                    DownloadOptionRow(
                        title: "Unmodified Originals",
                        subtitle: "Originals as captured or imported",
                        action: { onDownload(.unmodifiedOriginal) }
                    )
                }
                
                Section(header: Text("Including Edits")) {
                    DownloadOptionRow(
                        title: "Highest Resolution",
                        subtitle: "Typically includes HEIC or H.265 files",
                        action: { onDownload(.highestResolution) }
                    )
                    
                    DownloadOptionRow(
                        title: "Most Compatible",
                        subtitle: "JPEG or MP4/H.264 when possible",
                        action: { onDownload(.mostCompatible) }
                    )
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
            .background(colors.bg)
            .navigationTitle("Download Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 320, height: 480)
        #endif
    }
}

fileprivate struct DownloadOptionRow: View {
    @Environment(\.cupertinoColors) private var colors
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundStyle(colors.fg)
                    Text(subtitle)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(colors.mutedFg)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: Theme.Spacing.lg)
                
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(colors.primary)
                    .padding(Theme.Spacing.sm)
                    .background(colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
