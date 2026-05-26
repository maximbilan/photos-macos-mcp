import Foundation
import MCP
import Photos
import CoreLocation

enum SearchTools {

    static func searchPhotos(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)
        let startDateStr = String(arguments?["start_date"] ?? .string(""), strict: false) ?? ""
        let endDateStr = String(arguments?["end_date"] ?? .string(""), strict: false) ?? ""
        let mediaTypeStr = String(arguments?["media_type"] ?? .string("any"), strict: false) ?? "any"
        let isFavorite = Bool(arguments?["is_favorite"] ?? .bool(false), strict: false)
        let keyword = String(arguments?["keyword"] ?? .string(""), strict: false) ?? ""

        let options = PHFetchOptions()
        var predicates: [NSPredicate] = []

        if !startDateStr.isEmpty, let start = DateParsing.parse(startDateStr) {
            predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
        }
        if !endDateStr.isEmpty, let end = DateParsing.parseEndOfDay(endDateStr) ?? DateParsing.parse(endDateStr) {
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
            var assetRefs: [PHAsset] = []
            let filterLivePhoto = (mediaTypeStr == "live_photo")
            fetchResult.enumerateObjects { asset, _, _ in
                if filterLivePhoto && !asset.mediaSubtypes.contains(.photoLive) {
                    return
                }
                assets.append(PhotoKitHelpers.metadata(from: asset))
                assetRefs.append(asset)
            }

            var filtered = assets
            var keywordInfo: KeywordSearchInfo?
            if !keyword.isEmpty {
                let searchResult = await filterAssetsByKeywordWithFallback(assetRefs: assetRefs, keyword: keyword)
                let matchingIndices = searchResult.indices
                filtered = matchingIndices.map { assets[$0] }
                keywordInfo = searchResult.info
            }

            let total = filtered.count
            let slice = Array(filtered.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(SearchResponseWithKeywordInfo(
                assets: slice,
                total: total,
                limit: limit,
                offset: offset,
                keywordInfo: keywordInfo
            ))
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
                let distance = GeoUtils.haversineKm(lat1: lat, lon1: lon, lat2: loc.coordinate.latitude, lon2: loc.coordinate.longitude)
                if distance <= radiusKm {
                    results.append(PhotoKitHelpers.metadata(from: asset))
                }
            }

            let total = results.count
            let slice = Array(results.dropFirst(offset).prefix(limit))
            let json = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }

    static func getPhotosByDate(arguments: [String: Value]?) async throws -> CallTool.Result {
        let dateStr = String(arguments?["date"] ?? .string(""), strict: false) ?? ""
        let startDateStr = String(arguments?["start_date"] ?? .string(""), strict: false) ?? ""
        let endDateStr = String(arguments?["end_date"] ?? .string(""), strict: false) ?? ""
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        var startDate: Date?
        var endDate: Date?

        if !dateStr.isEmpty {
            if let d = DateParsing.parse(dateStr) {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC") ?? .current
                startDate = cal.startOfDay(for: d)
                if let start = startDate {
                    endDate = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001)
                }
            }
        } else {
            if !startDateStr.isEmpty { startDate = DateParsing.parse(startDateStr) }
            if !endDateStr.isEmpty { endDate = DateParsing.parseEndOfDay(endDateStr) ?? DateParsing.parse(endDateStr) }
        }

        var predicates: [NSPredicate] = []
        if let s = startDate { predicates.append(NSPredicate(format: "creationDate >= %@", s as NSDate)) }
        if let e = endDate { predicates.append(NSPredicate(format: "creationDate <= %@", e as NSDate)) }

        let options = PHFetchOptions()
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
            let json = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            return .init(content: [.text(json)], isError: false)
        }.value
    }

    /// Search photos by place name (city, country, etc.). Geocodes the name to coordinates, then finds photos nearby.
    static func getPhotosByPlace(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let placeName = String(arguments?["place"] ?? .string(""), strict: false), !placeName.isEmpty else {
            return .init(content: [.text("Error: place name is required (e.g. 'Valencia', 'New York', 'Paris')")], isError: true)
        }
        let radiusKm = Double(arguments?["radius_km"] ?? 25, strict: false) ?? 25
        let limit = min(Int(arguments?["limit"] ?? 50, strict: false) ?? 50, 200)
        let offset = max(Int(arguments?["offset"] ?? 0, strict: false) ?? 0, 0)

        let geocoder = CLGeocoder()
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CLPlacemark], Error>) in
                geocoder.geocodeAddressString(placeName) { marks, error in
                    if let error = error { cont.resume(throwing: error); return }
                    cont.resume(returning: marks ?? [])
                }
            }
        } catch {
            return .init(content: [.text("Error: Could not find '\(placeName)': \(error.localizedDescription)")], isError: true)
        }
        guard let loc = placemarks.first?.location else {
            return .init(content: [.text("Error: No coordinates for '\(placeName)'")], isError: true)
        }

        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude

        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
            var results: [PhotoKitHelpers.AssetMetadata] = []
            allPhotos.enumerateObjects { asset, _, _ in
                guard let assetLoc = asset.location else { return }
                let distance = GeoUtils.haversineKm(lat1: lat, lon1: lon, lat2: assetLoc.coordinate.latitude, lon2: assetLoc.coordinate.longitude)
                if distance <= radiusKm {
                    results.append(PhotoKitHelpers.metadata(from: asset))
                }
            }

            let total = results.count
            let slice = Array(results.dropFirst(offset).prefix(limit))
            var response = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.SearchResponse(assets: slice, total: total, limit: limit, offset: offset))
            response = "Place: \(placeName) (\(lat), \(lon)), radius \(radiusKm) km\n" + response
            return .init(content: [.text(response)], isError: false)
        }.value
    }
}

private struct KeywordSearchInfo: Encodable {
    let requestedKeyword: String
    let matchedKeyword: String?
    let usedFallback: Bool
    let fallbackKeywords: [String]
    let confidenceThreshold: Float
    let analyzedAssets: Int
    let maxAnalyzedAssets: Int
}

private struct KeywordFilterResult {
    let indices: [Int]
    let info: KeywordSearchInfo
}

private struct SearchResponseWithKeywordInfo: Encodable {
    let assets: [PhotoKitHelpers.AssetMetadata]
    let total: Int
    let limit: Int
    let offset: Int
    let keywordInfo: KeywordSearchInfo?
}

private func filterAssetsByKeywordWithFallback(assetRefs: [PHAsset], keyword: String) async -> KeywordFilterResult {
    let analyzedAssets = min(assetRefs.count, ContentClassifier.maxAssetsToAnalyze)
    let primaryThreshold = ContentClassifier.defaultConfidenceThreshold
    let fallbackThreshold: Float = 0.2
    let fallbackKeywords = ContentClassifier.fallbackKeywords(for: keyword)

    let primaryMatches = await filterAssetsByKeyword(
        assetRefs: assetRefs,
        keyword: keyword,
        confidenceThreshold: primaryThreshold
    )
    if !primaryMatches.isEmpty {
        return KeywordFilterResult(
            indices: primaryMatches,
            info: KeywordSearchInfo(
                requestedKeyword: keyword,
                matchedKeyword: keyword,
                usedFallback: false,
                fallbackKeywords: fallbackKeywords,
                confidenceThreshold: primaryThreshold,
                analyzedAssets: analyzedAssets,
                maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
            )
        )
    }

    for fallbackKeyword in fallbackKeywords {
        let fallbackMatches = await filterAssetsByKeyword(
            assetRefs: assetRefs,
            keyword: fallbackKeyword,
            confidenceThreshold: fallbackThreshold
        )
        if !fallbackMatches.isEmpty {
            return KeywordFilterResult(
                indices: fallbackMatches,
                info: KeywordSearchInfo(
                    requestedKeyword: keyword,
                    matchedKeyword: fallbackKeyword,
                    usedFallback: true,
                    fallbackKeywords: fallbackKeywords,
                    confidenceThreshold: fallbackThreshold,
                    analyzedAssets: analyzedAssets,
                    maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
                )
            )
        }
    }

    return KeywordFilterResult(
        indices: [],
        info: KeywordSearchInfo(
            requestedKeyword: keyword,
            matchedKeyword: nil,
            usedFallback: false,
            fallbackKeywords: fallbackKeywords,
            confidenceThreshold: primaryThreshold,
            analyzedAssets: analyzedAssets,
            maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
        )
    )
}

private func filterAssetsByKeyword(
    assetRefs: [PHAsset],
    keyword: String,
    confidenceThreshold: Float
) async -> [Int] {
    let maxAnalyze = min(assetRefs.count, ContentClassifier.maxAssetsToAnalyze)
    var matching: [Int] = []
    for i in 0..<maxAnalyze {
        let matches = await ContentClassifier.assetMatchesKeyword(
            asset: assetRefs[i],
            keyword: keyword,
            confidenceThreshold: confidenceThreshold
        )
        if matches { matching.append(i) }
    }
    return matching
}
