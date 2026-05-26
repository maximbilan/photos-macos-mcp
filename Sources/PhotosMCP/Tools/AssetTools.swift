import Foundation
import MCP
import Photos

enum AssetTools {

    static func getAssetDetails(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return .init(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            let meta = PhotoKitHelpers.metadata(from: asset)

            // Resource file sizes: PhotoKit does not expose a public fileSize API.
            // PHAssetResource's fileSize is private KVO; we omit it for API stability.
            let metaWithSizes = AssetMetadataWithSizes(
                identifier: meta.identifier,
                creationDate: meta.creationDate,
                modificationDate: meta.modificationDate,
                mediaType: meta.mediaType,
                mediaSubtypes: meta.mediaSubtypes,
                pixelWidth: meta.pixelWidth,
                pixelHeight: meta.pixelHeight,
                duration: meta.duration,
                isFavorite: meta.isFavorite,
                isHidden: meta.isHidden,
                location: meta.location,
                resourceFileSizes: nil
            )

            let json = try PhotoKitHelpers.encodeToJSON(metaWithSizes)
            return .init(content: [.text(json)], isError: false)
        }.value
    }

    static func getAssetClassifications(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }
        let maxResults = min(max(Int(arguments?["max_results"] ?? 10, strict: false) ?? 10, 1), 30)

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return CallTool.Result(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            guard asset.mediaType == .image else {
                return CallTool.Result(content: [.text("Error: Asset is not a photo (media type: \(asset.mediaType.rawValue))")], isError: true)
            }

            let classifications = await ContentClassifier.classifications(
                for: asset,
                maxResults: maxResults
            )
            let response = AssetClassificationsResponse(
                assetIdentifier: assetId,
                classifications: classifications
            )

            do {
                let json = try PhotoKitHelpers.encodeToJSON(response)
                return CallTool.Result(content: [.text(json)], isError: false)
            } catch {
                return CallTool.Result(content: [.text("Error: Failed to encode classifications: \(error.localizedDescription)")], isError: true)
            }
        }.value
    }
}

private struct AssetMetadataWithSizes: Encodable {
    let identifier: String
    let creationDate: String?
    let modificationDate: String?
    let mediaType: String
    let mediaSubtypes: [String]
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: Double?
    let isFavorite: Bool
    let isHidden: Bool
    let location: PhotoKitHelpers.AssetMetadata.Location?
    let resourceFileSizes: [Int]?
}

private struct AssetClassificationsResponse: Encodable {
    let assetIdentifier: String
    let classifications: [ContentClassifier.Classification]
}
