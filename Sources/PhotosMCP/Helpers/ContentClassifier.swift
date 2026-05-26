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

    struct Classification: Encodable, Sendable {
        let label: String
        let confidence: Float
    }

    /// Minimum confidence (0...1) for a classification match.
    static let defaultConfidenceThreshold: Float = 0.3

    /// Maximum number of assets to analyze when keyword filtering. Prevents long-running requests.
    static let maxAssetsToAnalyze = 1000

    /// Keyword synonyms for common searches (Vision labels may vary).
    private static let keywordSynonyms: [String: [String]] = [
        "pizza": ["pizza", "pie", "italian food", "food", "meal", "dish", "dough"],
        "food": ["food", "meal", "dish", "cuisine", "pizza", "sandwich", "salad"],
        "dog": ["dog", "puppy", "canine"],
        "cat": ["cat", "kitten", "feline"],
        "beach": ["beach", "shore", "sand", "ocean", "sea"],
        "sunset": ["sunset", "sundown", "dusk", "sky"],
        "landscape": ["landscape", "mountain", "nature", "scenery"],
        "car": ["car", "automobile", "vehicle", "sedan", "sports car", "truck"],
        "city": ["city", "urban", "street", "downtown", "skyscraper", "building", "architecture"],
        "person": ["person", "people", "human", "face", "portrait"],
        "people": ["person", "people", "human", "face", "portrait", "group"],
        "man": ["man", "men", "male", "person", "people", "human", "face", "portrait", "adult"],
        "men": ["man", "men", "male", "person", "people", "human", "face", "portrait", "adult"],
        "woman": ["woman", "women", "female", "person", "people", "human", "face", "portrait", "adult"],
        "women": ["woman", "women", "female", "person", "people", "human", "face", "portrait", "adult"],
        "boy": ["boy", "child", "children", "kid", "person", "people", "human", "face", "portrait"],
        "girl": ["girl", "child", "children", "kid", "person", "people", "human", "face", "portrait"],
        "child": ["child", "children", "kid", "boy", "girl", "person", "people", "human", "face", "portrait"],
        "children": ["child", "children", "kid", "boy", "girl", "person", "people", "human", "face", "portrait"],
        "baby": ["baby", "infant", "toddler", "child", "person", "people", "human", "face", "portrait"],
        "selfie": ["selfie", "person", "people", "human", "face", "portrait"],
        "portrait": ["portrait", "person", "people", "human", "face"]
    ]

    private static let personDetectionTerms: Set<String> = [
        "person", "people", "human", "face", "portrait", "selfie",
        "man", "men", "male", "woman", "women", "female",
        "boy", "girl", "child", "children", "kid", "baby", "infant", "toddler"
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

    static func classifications(
        for asset: PHAsset,
        maxResults: Int = 10,
        imageManager: PHImageManager = .default()
    ) async -> [Classification] {
        guard asset.mediaType == .image else { return [] }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { (cont: CheckedContinuation<[Classification], Never>) in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard let image = image else {
                    cont.resume(returning: [])
                    return
                }

                cont.resume(returning: classifications(
                    for: image,
                    maxResults: maxResults
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

        if usesPersonDetection(for: keyword), imageHasPerson(cgImage) {
            return true
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let allTerms = matchingTerms(for: keyword)
            let results = request.results ?? []

            for obs in results where obs.confidence >= confidenceThreshold {
                if classificationLabel(obs.identifier, matchesAny: allTerms) {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    static func matchingTerms(for keyword: String) -> Set<String> {
        let normalizedKeyword = normalize(keyword)
        guard !normalizedKeyword.isEmpty else { return [] }

        let synonyms = keywordSynonyms[normalizedKeyword] ?? []
        return Set((synonyms + [normalizedKeyword])
            .map(normalize)
            .filter { !$0.isEmpty })
    }

    static func classificationLabel(_ label: String, matchesKeyword keyword: String) -> Bool {
        classificationLabel(label, matchesAny: matchingTerms(for: keyword))
    }

    static func fallbackKeywords(for keyword: String) -> [String] {
        let normalizedKeyword = normalize(keyword)
        let fallbacksByKeyword: [String: [String]] = [
            "pizza": ["food", "meal", "dish", "cuisine", "restaurant"],
            "sandwich": ["food", "meal", "dish"],
            "salad": ["food", "meal", "dish"],
            "sushi": ["food", "meal", "dish", "cuisine", "restaurant"],
            "burger": ["food", "meal", "dish", "restaurant"],
            "dog": ["animal", "pet"],
            "cat": ["animal", "pet"],
            "beach": ["water", "ocean", "sea", "landscape"],
            "car": ["vehicle", "automobile", "transportation"]
        ]

        let fallbacks = fallbacksByKeyword[normalizedKeyword] ?? []
        return fallbacks.filter { $0 != normalizedKeyword }
    }

    static func usesPersonDetection(for keyword: String) -> Bool {
        !matchingTerms(for: keyword).isDisjoint(with: personDetectionTerms)
    }

    private static func classifications(
        for image: ClassifierImage,
        maxResults: Int
    ) -> [Classification] {
        let cgImage: CGImage?
        #if os(macOS)
        let nsImage = image
        cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            ?? (nsImage.representations.first as? NSBitmapImageRep)?.cgImage
        #else
        cgImage = image.cgImage
        #endif

        guard let cgImage = cgImage else { return [] }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return Array((request.results ?? [])
                .prefix(max(maxResults, 0))
                .map { Classification(label: $0.identifier, confidence: $0.confidence) })
        } catch {
            return []
        }
    }

    private static func imageHasPerson(_ cgImage: CGImage) -> Bool {
        let humanRequest = VNDetectHumanRectanglesRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest])
            return !(humanRequest.results ?? []).isEmpty || !(faceRequest.results ?? []).isEmpty
        } catch {
            return false
        }
    }

    private static func classificationLabel(_ label: String, matchesAny terms: Set<String>) -> Bool {
        let normalizedLabel = normalize(label)
        guard !normalizedLabel.isEmpty else { return false }

        return terms.contains { term in
            wholeTerm(term, appearsIn: normalizedLabel)
        }
    }

    private static func wholeTerm(_ term: String, appearsIn label: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        return label.range(
            of: "(^|[^a-z0-9])\(escaped)($|[^a-z0-9])",
            options: .regularExpression
        ) != nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }
}
