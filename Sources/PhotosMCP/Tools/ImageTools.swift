import Foundation
import MCP
import Photos

enum ImageTools {

    static func getPhotoThumbnail(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }
        let maxDimension = Int(arguments?["max_dimension"] ?? 512, strict: false) ?? 512
        let quality = CGFloat(Double(arguments?["quality"] ?? 0.8, strict: false) ?? 0.8)

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return .init(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            guard asset.mediaType == .image else {
                return .init(content: [.text("Error: Asset is not a photo (media type: \(asset.mediaType.rawValue))")], isError: true)
            }

            do {
                let imageData = try await ImageExport.thumbnail(asset: asset, maxDimension: maxDimension, quality: quality)
                let base64 = imageData.base64EncodedString()
                let metadata: [String: String] = [
                    "width": "\(min(asset.pixelWidth, maxDimension))",
                    "height": "\(min(asset.pixelHeight, maxDimension))"
                ]
                return .init(
                    content: [.image(data: base64, mimeType: "image/jpeg", metadata: metadata)],
                    isError: false
                )
            } catch {
                return .init(
                    content: [.text("Error: Failed to export thumbnail: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }.value
    }

    static func getPhotoFull(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }
        let maxDimension = arguments?["max_dimension"].flatMap { Int($0, strict: false) }
        let quality = CGFloat(Double(arguments?["quality"] ?? 0.8, strict: false) ?? 0.8)

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return .init(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            guard asset.mediaType == .image else {
                return .init(content: [.text("Error: Asset is not a photo (media type: \(asset.mediaType.rawValue))")], isError: true)
            }

            var warning: String?
            if maxDimension == nil && (asset.pixelWidth > 4000 || asset.pixelHeight > 4000) {
                warning = "Warning: Full-resolution image is large (\(asset.pixelWidth)x\(asset.pixelHeight)). Consider max_dimension (e.g. 2048) to downscale."
            }

            do {
                let imageData = try await ImageExport.fullImage(
                    asset: asset,
                    maxDimension: maxDimension,
                    quality: quality
                )
                let base64 = imageData.base64EncodedString()
                let outW = maxDimension.map { min(asset.pixelWidth, $0) } ?? asset.pixelWidth
                let outH = maxDimension.map { min(asset.pixelHeight, $0) } ?? asset.pixelHeight
                let metadata: [String: String] = [
                    "width": "\(outW)",
                    "height": "\(outH)"
                ]
                var content: [Tool.Content] = [
                    .text("Image size: \(imageData.count) bytes, dimensions: \(outW)x\(outH)"),
                    .image(data: base64, mimeType: "image/jpeg", metadata: metadata)
                ]
                if let w = warning {
                    content.insert(.text(w), at: 0)
                }
                return .init(content: content, isError: false)
            } catch {
                return .init(
                    content: [.text("Error: Failed to export image: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }.value
    }
}
