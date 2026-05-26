import Foundation
import Photos
import Vision

#if os(macOS)
import AppKit
fileprivate typealias ClassifierImage = NSImage
#else
import UIKit
fileprivate typealias ClassifierImage = UIImage
#endif

/// Uses Vision framework to classify images and match against keywords (e.g., "pizza", "food").
/// PhotoKit does not expose Apple's ML search API, so we run on-device classification.
enum ContentClassifier {

    /// Minimum confidence (0...1) for a classification match.
    static let defaultConfidenceThreshold: Float = 0.3

    /// Maximum number of assets to analyze when keyword filtering. Prevents long-running requests.
    static let maxAssetsToAnalyze = 1000

    /// Keyword synonyms for common searches (Vision labels may vary).
    private static let keywordSynonyms: [String: [String]] = [
        "pizza": ["pizza", "pie", "Italian food", "food", "meal", "dough"],
        "food": ["food", "meal", "dish", "cuisine", "pizza", "sandwich", "salad"],
        "dog": ["dog", "puppy", "canine"],
        "cat": ["cat", "kitten", "feline"],
        "beach": ["beach", "shore", "sand", "ocean", "sea"],
        "sunset": ["sunset", "sundown", "dusk", "sky"],
        "landscape": ["landscape", "mountain", "nature", "scenery"],
        "car": ["car", "automobile", "vehicle", "sedan", "sports car", "truck"],
        "city": ["city", "urban", "street", "downtown", "skyscraper", "building", "architecture"],
        "person": ["person", "people", "human", "face", "portrait"],
        "people": ["person", "people", "human", "face", "group"]
    ]

    /// Check if an asset's image matches the given keyword using Vision classification.
    static func assetMatchesKeyword(
        asset: PHAsset,
        keyword: String,
        imageManager: PHImageManager = .default(),
        confidenceThreshold: Float = defaultConfidenceThreshold
    ) async -> Bool {
        guard asset.mediaType == .image else { return false }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 384, height: 384),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard let image = image else {
                    cont.resume(returning: false)
                    return
                }

                cont.resume(returning: imageMatchesKeyword(
                    image: image,
                    keyword: keyword,
                    confidenceThreshold: confidenceThreshold
                ))
            }
        }
    }

    /// Classify image and check if it matches the keyword.
    fileprivate static func imageMatchesKeyword(
        image: ClassifierImage,
        keyword: String,
        confidenceThreshold: Float = defaultConfidenceThreshold
    ) -> Bool {
        let cgImage: CGImage?
        #if os(macOS)
        let nsImage = image
        cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            ?? (nsImage.representations.first as? NSBitmapImageRep)?.cgImage
        #else
        cgImage = image.cgImage
        #endif

        guard let cgImage = cgImage else { return false }

        var didMatch = false
        let request = VNClassifyImageRequest { req, error in
            guard error == nil, let results = req.results as? [VNClassificationObservation] else {
                return
            }

            let keywordLower = keyword.lowercased().trimmingCharacters(in: .whitespaces)
            let synonyms = Self.keywordSynonyms[keywordLower] ?? [keywordLower]
            let allTerms = Set(synonyms + [keywordLower])

            for obs in results where obs.confidence >= confidenceThreshold {
                let label = obs.identifier.lowercased()
                if allTerms.contains(where: { label.contains($0) || $0.contains(label) }) {
                    didMatch = true
                    return
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return didMatch
        } catch {
            return false
        }
    }
}
