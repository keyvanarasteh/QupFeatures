import SwiftUI
import PhotosUI

/// Extensions to bridge `PhotosPickerItem` (from `PhotosUI`) smoothly into `iCloudCore` environments.
@available(iOS 16.0, macOS 13.0, *)
public extension PhotosPickerItem {
    
    /// Asynchronously loads a SwiftUI `Image` from the selected picker item.
    /// This is useful for displaying the selected photo immediately in a UI.
    func loadTransferableImage() async throws -> Image? {
        return try await self.loadTransferable(type: Image.self)
    }
    
    /// Asynchronously loads raw `Data` and the associated MIME type string from the selected picker item.
    /// This is useful when you need to upload the image to a server (e.g. avatar or header updates).
    func loadTransferableData() async throws -> (data: Data, mimeType: String)? {
        guard let data = try await self.loadTransferable(type: Data.self) else {
            return nil
        }
        
        // Use the first supported content type as the best-guess MIME, fallback to octet-stream
        let mimeType = self.supportedContentTypes.first?.preferredMIMEType ?? "application/octet-stream"
        return (data, mimeType)
    }
}
