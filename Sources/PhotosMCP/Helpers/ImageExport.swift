import Foundation
import Photos
import ImageIO
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Double(compressionQuality))])
    }
}
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// Handles image export from PHAsset to base64-encoded JPEG for MCP.
enum ImageExport {

    static func thumbnail(
        asset: PHAsset,
        maxDimension: Int = 512,
        quality: CGFloat = 0.8
    ) async throws -> Data {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast

        let targetSize = CGSize(width: maxDimension, height: maxDimension)

        return try await withCheckedThrowingContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image = image else {
                    continuation.resume(throwing: ImageExportError.noImage)
                    return
                }
                do {
                    let jpegData = try imageToJPEGData(image, quality: quality)
                    continuation.resume(returning: jpegData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func fullImage(
        asset: PHAsset,
        maxDimension: Int? = nil,
        quality: CGFloat = 0.8
    ) async throws -> Data {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = maxDimension != nil ? .fast : .none

        let targetSize: CGSize
        if let max = maxDimension, max > 0 {
            let scale = min(CGFloat(max) / CGFloat(asset.pixelWidth), CGFloat(max) / CGFloat(asset.pixelHeight))
            if scale < 1 {
                targetSize = CGSize(
                    width: Int(CGFloat(asset.pixelWidth) * scale),
                    height: Int(CGFloat(asset.pixelHeight) * scale)
                )
            } else {
                targetSize = PHImageManagerMaximumSize
            }
        } else {
            targetSize = PHImageManagerMaximumSize
        }

        return try await withCheckedThrowingContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image = image else {
                    continuation.resume(throwing: ImageExportError.noImage)
                    return
                }
                do {
                    let jpegData = try imageToJPEGData(image, quality: quality)
                    continuation.resume(returning: jpegData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func imageToJPEGData(_ image: PlatformImage, quality: CGFloat) throws -> Data {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw ImageExportError.encodingFailed
        }
        return data
    }
}

enum ImageExportError: Error, LocalizedError {
    case noImage
    case encodingFailed
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .noImage: return "Could not load image from asset"
        case .encodingFailed: return "Failed to encode image as JPEG"
        case .assetNotFound: return "Asset not found"
        }
    }
}
