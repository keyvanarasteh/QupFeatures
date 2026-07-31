import Combine
import Foundation
import Photos
import SwiftUI

/// Represents a media item with its calculated file size for sorting.
public struct MediaItemSize: Identifiable, Equatable, @unchecked Sendable {
    public let id: String
    public let asset: PHAsset
    public let sizeBytes: Int64
    
    public init(asset: PHAsset, sizeBytes: Int64) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.sizeBytes = sizeBytes
    }
}

/// Asynchronously scans a `PHFetchResult` and calculates the sizes of all assets.
@MainActor
public class PhotoSizeIndexer: ObservableObject {
    @Published public var indexedItems: [MediaItemSize] = []
    @Published public var isIndexing = false
    @Published public var progress: Double = 0.0
    
    private var scanTask: Task<Void, Never>?
    
    public init() {}
    
    @MainActor
    private func updateItemsAndProgress(_ items: [MediaItemSize], progress: Double) {
        self.indexedItems = items
        self.progress = progress
    }
    
    @MainActor
    private func setIndexing(_ indexing: Bool) {
        self.isIndexing = indexing
    }
    
    public func startIndexing(fetchResult: PHFetchResult<PHAsset>) {
        scanTask?.cancel()
        indexedItems.removeAll()
        isIndexing = true
        progress = 0.0
        
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let total = fetchResult.count
            guard total > 0 else {
                await self.setIndexing(false)
                return
            }
            
            var allItems: [MediaItemSize] = []
            let manager = PhotoKitManager.shared
            
            for i in 0..<total {
                if Task.isCancelled { break }
                
                let asset = fetchResult.object(at: i)
                let size = manager.calculateSize(for: asset)
                allItems.append(MediaItemSize(asset: asset, sizeBytes: size))
                
                // Update UI every 50 items to keep it responsive but avoid overhead
                if i % 50 == 0 || i == total - 1 {
                    allItems.sort { $0.sizeBytes > $1.sizeBytes }
                    let currentItems = allItems
                    let progressValue = Double(i + 1) / Double(total)
                    await self.updateItemsAndProgress(currentItems, progress: progressValue)
                }
            }
            
            await self.setIndexing(false)
        }
    }
    
    public func stopIndexing() {
        scanTask?.cancel()
        isIndexing = false
    }
}
