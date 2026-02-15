import Foundation
import MCP
import Photos

enum LibraryTools {

    static func listAlbums(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        return try await Task.detached(priority: .userInitiated) {
            let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

            var albums: [PhotoKitHelpers.AlbumMetadata] = []

            for i in 0..<smartAlbums.count {
                let col = smartAlbums.object(at: i)
                if let meta = PhotoKitHelpers.albumMetadata(from: col) {
                    albums.append(meta)
                }
            }

            for i in 0..<topLevel.count {
                let col = topLevel.object(at: i)
                if let assetCol = col as? PHAssetCollection, let meta = PhotoKitHelpers.albumMetadata(from: assetCol) {
                    albums.append(meta)
                } else if let folder = col as? PHCollectionList {
                    let sub = PHCollection.fetchCollections(in: folder, options: nil)
                    for j in 0..<sub.count {
                        let c = sub.object(at: j)
                        if let ac = c as? PHAssetCollection, let meta = PhotoKitHelpers.albumMetadata(from: ac) {
                            albums.append(meta)
                        }
                    }
                }
            }

            let total = albums.count
            let slice = Array(albums.dropFirst(offset).prefix(limit))

            let json: [String: Any] = [
                "albums": slice.map { a in
                    [
                        "identifier": a.identifier,
                        "name": a.name,
                        "asset_count": a.assetCount,
                        "type": a.type
                    ] as [String: Any]
                },
                "total": total,
                "limit": limit,
                "offset": offset
            ]

            let data = try JSONSerialization.data(withJSONObject: json)
            let str = String(data: data, encoding: .utf8) ?? "{}"
            return .init(content: [.text(str)], isError: false)
        }.value
    }

    static func getLibraryStats(arguments: [String: Value]?) async throws -> CallTool.Result {
        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: nil)
            var photoCount = 0
            var videoCount = 0
            var earliest: Date?
            var latest: Date?

            allPhotos.enumerateObjects { asset, _, _ in
                switch asset.mediaType {
                case .image: photoCount += 1
                case .video: videoCount += 1
                default: break
                }
                if let d = asset.creationDate {
                    if let e = earliest {
                        if d < e { earliest = d }
                    } else {
                        earliest = d
                    }
                    if let l = latest {
                        if d > l { latest = d }
                    } else {
                        latest = d
                    }
                }
            }

            let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            let albumCount = topLevel.count + smartAlbums.count

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(identifier: "UTC")

            let json: [String: Any] = [
                "photos": photoCount,
                "videos": videoCount,
                "total_assets": photoCount + videoCount,
                "albums": albumCount,
                "date_range": [
                    "earliest": earliest.map { formatter.string(from: $0) } as Any,
                    "latest": latest.map { formatter.string(from: $0) } as Any
                ] as [String: Any]
            ]

            let data = try JSONSerialization.data(withJSONObject: json)
            let str = String(data: data, encoding: .utf8) ?? "{}"
            return .init(content: [.text(str)], isError: false)
        }.value
    }

    static func listMoments(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        return try await Task.detached(priority: .userInitiated) {
            // fetchMoments is unavailable on macOS - return empty with info
            var list: [PhotoKitHelpers.MomentMetadata] = []
            #if os(iOS)
            let moments = PHAssetCollection.fetchMoments(with: nil)
            moments.enumerateObjects { moment, _, _ in
                list.append(PhotoKitHelpers.momentMetadata(from: moment))
            }
            #endif

            let total = list.count
            let slice = Array(list.dropFirst(offset).prefix(limit))

            let momentsArray = slice.map { m -> [String: Any] in
                [
                    "identifier": m.identifier,
                    "title": m.title as Any,
                    "start_date": m.startDate as Any,
                    "end_date": m.endDate as Any,
                    "location_names": m.locationNames,
                    "asset_count": m.assetCount
                ]
            }

            let jsonObj: [String: Any] = [
                "moments": momentsArray,
                "total": total,
                "limit": limit,
                "offset": offset
            ]

            let data = try JSONSerialization.data(withJSONObject: jsonObj)
            let str = String(data: data, encoding: .utf8) ?? "{}"
            return .init(content: [.text(str)], isError: false)
        }.value
    }
}
