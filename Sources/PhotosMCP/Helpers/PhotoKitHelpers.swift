import Foundation
import Photos

/// JSON-friendly representations of PhotoKit entities for MCP tool responses.
enum PhotoKitHelpers {

    // MARK: - Asset Metadata

    struct AssetMetadata: Encodable, Sendable {
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
        let location: Location?
        let resourceFileSizes: [Int]?

        struct Location: Encodable, Sendable {
            let latitude: Double
            let longitude: Double
        }
    }

    static func metadata(from asset: PHAsset) -> AssetMetadata {
        let location: AssetMetadata.Location?
        if let loc = asset.location {
            location = .init(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        } else {
            location = nil
        }

        var subtypes: [String] = []
        if asset.mediaSubtypes.contains(.photoPanorama) { subtypes.append("panorama") }
        if asset.mediaSubtypes.contains(.photoHDR) { subtypes.append("hdr") }
        if asset.mediaSubtypes.contains(.photoScreenshot) { subtypes.append("screenshot") }
        if asset.mediaSubtypes.contains(.photoLive) { subtypes.append("live") }
        if asset.mediaSubtypes.contains(.videoHighFrameRate) { subtypes.append("high_frame_rate") }
        if asset.mediaSubtypes.contains(.videoTimelapse) { subtypes.append("timelapse") }
        if asset.mediaSubtypes.contains(.videoStreamed) { subtypes.append("streamed") }
        if subtypes.isEmpty { subtypes.append("none") }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")

        return AssetMetadata(
            identifier: asset.localIdentifier,
            creationDate: asset.creationDate.map { formatter.string(from: $0) },
            modificationDate: asset.modificationDate.map { formatter.string(from: $0) },
            mediaType: mediaTypeString(asset.mediaType),
            mediaSubtypes: subtypes,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            duration: asset.mediaType == .video ? asset.duration : nil,
            isFavorite: asset.isFavorite,
            isHidden: asset.isHidden,
            location: location,
            resourceFileSizes: nil // Populated separately when available
        )
    }

    static func mediaTypeString(_ type: PHAssetMediaType) -> String {
        switch type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "audio"
        default: return "unknown"
        }
    }

    // MARK: - Album Metadata

    struct AlbumMetadata: Encodable, Sendable {
        let identifier: String
        let name: String
        let assetCount: Int
        let type: String // "album" | "smart_album" | "moment"
    }

    static func albumMetadata(from collection: PHCollection) -> AlbumMetadata? {
        guard let assetCollection = collection as? PHAssetCollection else { return nil }
        let count = PHAsset.fetchAssets(in: assetCollection, options: nil).count
        let type: String
        if assetCollection.assetCollectionSubtype == .smartAlbumUserLibrary ||
            assetCollection.assetCollectionSubtype.rawValue >= 200 {
            type = "smart_album"
        } else {
            type = "album"
        }
        return AlbumMetadata(
            identifier: assetCollection.localIdentifier,
            name: assetCollection.localizedTitle ?? "Unknown",
            assetCount: count,
            type: type
        )
    }

    // MARK: - Moment Metadata

    struct MomentMetadata: Encodable, Sendable {
        let identifier: String
        let title: String?
        let startDate: String?
        let endDate: String?
        let locationNames: [String]
        let assetCount: Int
    }

    static func momentMetadata(from moment: PHAssetCollection) -> MomentMetadata {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")

        let count = PHAsset.fetchAssets(in: moment, options: nil).count
        let locationNames = moment.localizedLocationNames

        return MomentMetadata(
            identifier: moment.localIdentifier,
            title: moment.localizedTitle,
            startDate: moment.startDate.map { formatter.string(from: $0) },
            endDate: moment.endDate.map { formatter.string(from: $0) },
            locationNames: locationNames,
            assetCount: count
        )
    }

    // MARK: - Encoding Helpers

    static func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PhotoKitHelpers", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"])
        }
        return str
    }
}
