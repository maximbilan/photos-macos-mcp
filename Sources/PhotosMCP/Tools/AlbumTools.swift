import Foundation
import MCP
import Photos

enum AlbumTools {

    static func getAlbumContents(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let albumId = String(arguments?["album_identifier"] ?? .string(""), strict: false), !albumId.isEmpty else {
            return .init(content: [.text("Error: album_identifier is required")], isError: true)
        }
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        return try await Task.detached(priority: .userInitiated) {
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
            guard let collection = collections.firstObject else {
                return .init(content: [.text("Error: Album not found with identifier \(albumId)")], isError: true)
            }

            let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            var assets: [PhotoKitHelpers.AssetMetadata] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(PhotoKitHelpers.metadata(from: asset))
            }

            let total = assets.count
            let slice = Array(assets.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }
}
