import Foundation
import MCP
import Photos

enum SearchTools {

    static func searchPhotos(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)
        let startDateStr = String(arguments?["start_date"] ?? .string(""), strict: false) ?? ""
        let endDateStr = String(arguments?["end_date"] ?? .string(""), strict: false) ?? ""
        let mediaTypeStr = String(arguments?["media_type"] ?? .string("any"), strict: false) ?? "any"
        let isFavorite = Bool(arguments?["is_favorite"] ?? .bool(false), strict: false)
        let keyword = String(arguments?["keyword"] ?? .string(""), strict: false) ?? ""

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var options = PHFetchOptions()
        var predicates: [NSPredicate] = []

        if !startDateStr.isEmpty, let start = formatter.date(from: startDateStr) {
            predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
        }
        if !endDateStr.isEmpty, let end = formatter.date(from: endDateStr) {
            predicates.append(NSPredicate(format: "creationDate <= %@", end as NSDate))
        }
        if let fav = isFavorite, fav {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult: PHFetchResult<PHAsset>
            switch mediaTypeStr {
            case "photo":
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            case "video":
                fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            case "live_photo":
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            default:
                fetchResult = PHAsset.fetchAssets(with: options)
            }

            var assets: [PhotoKitHelpers.AssetMetadata] = []
            let filterLivePhoto = (mediaTypeStr == "live_photo")
            fetchResult.enumerateObjects { asset, _, _ in
                if filterLivePhoto && !asset.mediaSubtypes.contains(.photoLive) {
                    return
                }
                assets.append(PhotoKitHelpers.metadata(from: asset))
            }

            // Keyword search via PHFetchOptions - PhotoKit doesn't have direct keyword search
            // We could use PHCollection or search metadata, but for now we skip keyword
            // if keyword is provided, we'd need to filter by asset resources or use ML – simplified here
            var filtered = assets
            if !keyword.isEmpty {
                filtered = filtered.filter { _ in true } // Placeholder - keyword search limited in PhotoKit
            }

            let total = filtered.count
            let slice = Array(filtered.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }

    static func getPhotosByLocation(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let lat = Double(arguments?["latitude"] ?? 0, strict: false),
              let lon = Double(arguments?["longitude"] ?? 0, strict: false) else {
            return .init(content: [.text("Error: latitude and longitude are required")], isError: true)
        }
        let radiusKm = Double(arguments?["radius_km"] ?? 10, strict: false) ?? 10
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
            var results: [PhotoKitHelpers.AssetMetadata] = []
            allPhotos.enumerateObjects { asset, _, _ in
                guard let loc = asset.location else { return }
                let distance = haversineKm(lat1: lat, lon1: lon, lat2: loc.coordinate.latitude, lon2: loc.coordinate.longitude)
                if distance <= radiusKm {
                    results.append(PhotoKitHelpers.metadata(from: asset))
                }
            }

            let total = results.count
            let slice = Array(results.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }

    static func getPhotosByDate(arguments: [String: Value]?) async throws -> CallTool.Result {
        let dateStr = String(arguments?["date"] ?? .string(""), strict: false) ?? ""
        let startDateStr = String(arguments?["start_date"] ?? .string(""), strict: false) ?? ""
        let endDateStr = String(arguments?["end_date"] ?? .string(""), strict: false) ?? ""
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var startDate: Date?
        var endDate: Date?

        if !dateStr.isEmpty {
            if let d = formatter.date(from: dateStr) {
                let cal = Calendar.current
                startDate = cal.startOfDay(for: d)
                if let start = startDate {
                    endDate = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001)
                }
            }
        } else {
            if !startDateStr.isEmpty { startDate = formatter.date(from: startDateStr) }
            if !endDateStr.isEmpty { endDate = formatter.date(from: endDateStr) }
        }

        var predicates: [NSPredicate] = []
        if let s = startDate { predicates.append(NSPredicate(format: "creationDate >= %@", s as NSDate)) }
        if let e = endDate { predicates.append(NSPredicate(format: "creationDate <= %@", e as NSDate)) }

        var options = PHFetchOptions()
        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(with: options)
            var assets: [PhotoKitHelpers.AssetMetadata] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(PhotoKitHelpers.metadata(from: asset))
            }
            let total = assets.count
            let slice = Array(assets.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }
}

private struct SearchResponse: Encodable {
    let assets: [PhotoKitHelpers.AssetMetadata]
    let total: Int
    let limit: Int
    let offset: Int
}

private func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0 // Earth radius in km
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2)*sin(dLat/2) +
        cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
        sin(dLon/2)*sin(dLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    return R * c
}
