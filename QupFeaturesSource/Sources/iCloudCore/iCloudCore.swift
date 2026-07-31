import Foundation
import Photos
import QupCore
import DesignSystem

/// Defines the export/download options for an asset.
public enum PhotoDownloadOption: Sendable {
    /// Originals as captured or imported.
    case unmodifiedOriginal
    /// Typically includes HEIC or H.265 files (with edits if applicable).
    case highestResolution
    /// JPEG or MP4/H.264 when possible.
    case mostCompatible
}

/// Represents the types of collections/albums available in the Photo Library.
public enum PhotoCollectionType: CaseIterable, Sendable {
    case library
    case favorites
    case recents
    case videos
    case livePhotos
    case portrait
    case panoramas
    case timeLapse
    case sloMo
    case bursts
    case screenshots
    case animated
    case hidden
    case recentlyDeleted
    case userAlbums
    case sharedAlbums
}

/// Initial namespace and manager for PhotoKit integrations.
public actor PhotoKitManager {
    public static let shared = PhotoKitManager()

    private init() {}

    /// Requests Photo library access if not already determined.
    public func requestAccess() async -> Bool {
        return await PhotosAccess.requestPermission()
    }

    /// Fetches the `PHAssetCollection` for a given standard collection type.
    /// Note: Some collections (like Hidden or Recently Deleted) may require
    /// user authentication or specific iOS versions.
    public func fetchCollection(for type: PhotoCollectionType) -> [PHAssetCollection] {
        var collections: [PHAssetCollection] = []
        
        switch type {
        case .favorites:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .recents:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyAdded, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .videos:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumVideos, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .livePhotos:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLivePhotos, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .portrait:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumDepthEffect, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .panoramas:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumPanoramas, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .timeLapse:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumTimelapses, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .sloMo:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSlomoVideos, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .bursts:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumBursts, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .screenshots:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .animated:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .hidden:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAllHidden, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .recentlyDeleted:
            // PhotoKit has no public PHAssetCollectionSubtype for "Recently Deleted";
            // the system album isn't fetchable this way.
            break
        case .userAlbums:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .sharedAlbums:
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        case .library:
            // The entire library is typically fetched via PHAsset.fetchAssets(with: nil)
            // But to provide a collection, we use the UserLibrary smart album (Camera Roll).
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
            fetchResult.enumerateObjects { collection, _, _ in collections.append(collection) }
        }
        
        return collections
    }

    /// Fetches all assets within a specific collection, or the entire library if nil.
    public func fetchAssets(in collection: PHAssetCollection? = nil) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if let collection = collection {
            return PHAsset.fetchAssets(in: collection, options: options)
        } else {
            return PHAsset.fetchAssets(with: options)
        }
    }

    /// Returns the ideal `PHImageRequestOptions` and `PHVideoRequestOptions` based on the selected `PhotoDownloadOption`.
    public nonisolated func requestOptions(for downloadOption: PhotoDownloadOption) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true // Allow downloading from iCloud
        
        switch downloadOption {
        case .unmodifiedOriginal:
            options.version = .original
            options.deliveryMode = .highQualityFormat
        case .highestResolution:
            options.version = .current
            options.deliveryMode = .highQualityFormat
        case .mostCompatible:
            options.version = .current
            // For true compatibility transcodes, PHAssetExportRequest is typically used.
            // However, for image requests, we ask for high quality and we might need to handle the conversion
            // of HEIC to JPEG manually depending on the target destination.
            options.deliveryMode = .highQualityFormat
        }
        
        return options
    }

    /// Requests image data for a given asset asynchronously.
    public func requestImageData(for asset: PHAsset, options: PHImageRequestOptions? = nil) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let data = data {
                    continuation.resume(returning: data)
                } else {
                    let description = (info?[PHImageErrorKey] as? NSError)?.localizedDescription
                    continuation.resume(throwing: PhotoKitError.imageRequestFailed(description))
                }
            }
        }
    }

    /// Observes the photo library for changes, yielding `PHChange` objects as an `AsyncStream`.
    public nonisolated func observeChanges() -> AsyncStream<PHChange> {
        AsyncStream { continuation in
            let observer = LibraryObserver(continuation: continuation)
            PHPhotoLibrary.shared().register(observer)
            
            continuation.onTermination = { @Sendable _ in
                PHPhotoLibrary.shared().unregisterChangeObserver(observer)
            }
        }
    }

    /// Calculates the total file size in bytes for a given asset.
    public nonisolated func calculateSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Exports an asset to a specified directory based on the download option.
    public nonisolated func exportAsset(_ asset: PHAsset, option: PhotoDownloadOption, to destination: URL) async throws -> URL {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            throw PhotoKitError.imageRequestFailed(nil)
        }
        
        let fileURL = destination.appendingPathComponent(resource.originalFilename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        return fileURL
    }
}

public enum PhotoKitError: Error, Sendable {
    case imageRequestFailed(String?)
}

private class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    let continuation: AsyncStream<PHChange>.Continuation
    
    init(continuation: AsyncStream<PHChange>.Continuation) {
        self.continuation = continuation
        super.init()
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        continuation.yield(changeInstance)
    }
}
