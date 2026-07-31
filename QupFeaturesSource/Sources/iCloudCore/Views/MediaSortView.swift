import SwiftUI
import Photos
import QupCore
import DesignSystem

public struct MediaSortView: View {
    @StateObject private var indexer = PhotoSizeIndexer()
    @State private var selectedCollectionType: PhotoCollectionType = .library
    @State private var selection = Set<String>()
    @State private var isShowingDownloadSheet = false
    @State private var hasPermission = true
    
    public init() {}
    
    private var collectionTitle: String {
        switch selectedCollectionType {
        case .library: return "Library"
        case .videos: return "Videos"
        case .livePhotos: return "Live Photos"
        default: return "Media"
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if !hasPermission {
                EmptyStateView(
                    title: "Photos Access Required",
                    message: "CUPERTINO requires Photo Library access to scan and sort your media files.",
                    systemImage: "photo.badge.plus",
                    actionTitle: "Open Settings"
                ) {
                    PhotosAccess.openSettings()
                }
                .frame(maxHeight: .infinity)
            } else if indexer.isIndexing {
                ProgressView("Scanning library...", value: indexer.progress, total: 1.0)
                    .padding()
            } else if indexer.indexedItems.isEmpty {
                EmptyStateView(
                    title: "No Media Found",
                    message: "No items were found in your \"\(collectionTitle)\" collection.",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(indexer.indexedItems) { item in
                        MediaItemRow(item: item)
                            .tag(item.id)
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #else
                .listStyle(.plain)
                #endif
            }
        }
        .navigationTitle("Media Sizes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingDownloadSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(.body, design: .default, weight: .regular))
                }
                .disabled(selection.isEmpty)
                .accessibilityLabel("Download selected items")
                .help("Download selected items")
            }
            
            ToolbarItem(placement: .navigation) {
                Picker("Collection", selection: $selectedCollectionType) {
                    Text("Library").tag(PhotoCollectionType.library)
                    Text("Videos").tag(PhotoCollectionType.videos)
                    Text("Live Photos").tag(PhotoCollectionType.livePhotos)
                }
                .pickerStyle(.menu)
                .onChange(of: selectedCollectionType) { _, newType in
                    Task {
                        if hasPermission {
                            await loadCollection(type: newType)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDownloadSheet) {
            DownloadOptionsSheet(
                itemsCount: selection.count,
                thumbnailImage: nil, // Ideally, generate a thumbnail from the first selected asset
                onDownload: { option in
                    // Handle download option
                    isShowingDownloadSheet = false
                    downloadSelectedItems(option: option)
                }
            )
            #if os(macOS)
            .frame(width: 350, height: 450)
            #endif
        }
        .task {
            // Request permissions before loading
            hasPermission = await PhotoKitManager.shared.requestAccess()
            if hasPermission {
                await loadCollection(type: selectedCollectionType)
            }
        }
        .onDisappear {
            indexer.stopIndexing()
        }
    }
    
    private func loadCollection(type: PhotoCollectionType) async {
        let collections = await PhotoKitManager.shared.fetchCollection(for: type)
        // For simplicity, just use the first matching collection, or nil for library
        let collection = collections.first
        let assets = await PhotoKitManager.shared.fetchAssets(in: collection)
        indexer.startIndexing(fetchResult: assets)
    }
    
    private func downloadSelectedItems(option: PhotoDownloadOption) {
        let selectedAssets = indexer.indexedItems.filter { selection.contains($0.id) }.map { $0.asset }
        // Iterate and export these using PhotoKitManager.shared.exportAsset
        Task {
            // Download logic here to a local temp folder or Documents
            for asset in selectedAssets {
                let tempDir = FileManager.default.temporaryDirectory
                _ = try? await PhotoKitManager.shared.exportAsset(asset, option: option, to: tempDir)
            }
        }
    }
}

fileprivate struct MediaItemRow: View {
    let item: MediaItemSize
    @State private var thumbnail: Image?
    
    var body: some View {
        HStack {
            if let thumbnail = thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        ProgressView().scaleEffect(0.5)
                    }
            }
            
            VStack(alignment: .leading) {
                Text(item.asset.localIdentifier.components(separatedBy: "/").first ?? "Media")
                    .font(.body)
                    .lineLimit(1)
                Text(formatSize(item.sizeBytes))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if item.asset.mediaType == .video {
                Text(formatDuration(item.asset.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        PHImageManager.default().requestImage(for: item.asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: options) { uiImage, _ in
            if let uiImage = uiImage {
                #if os(macOS)
                self.thumbnail = Image(nsImage: uiImage)
                #else
                self.thumbnail = Image(uiImage: uiImage)
                #endif
            }
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }
}
