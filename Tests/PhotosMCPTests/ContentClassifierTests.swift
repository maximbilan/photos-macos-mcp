import Testing
@testable import PhotosMCP

struct ContentClassifierTests {

    @Test("man expands to Vision person labels")
    func manExpandsToPersonLabels() {
        let terms = ContentClassifier.matchingTerms(for: "man")

        #expect(terms.contains("man"))
        #expect(terms.contains("person"))
        #expect(terms.contains("people"))
        #expect(terms.contains("human"))
        #expect(terms.contains("face"))
    }

    @Test("matching is case-insensitive and uses synonym labels")
    func matchingUsesNormalizedSynonyms() {
        #expect(ContentClassifier.classificationLabel("Person", matchesKeyword: "man"))
        #expect(ContentClassifier.classificationLabel("human face", matchesKeyword: "man"))
        #expect(ContentClassifier.classificationLabel("Italian food", matchesKeyword: "pizza"))
    }

    @Test("person-like keywords use human and face detection")
    func personKeywordsUsePersonDetection() {
        #expect(ContentClassifier.usesPersonDetection(for: "man"))
        #expect(ContentClassifier.usesPersonDetection(for: "person"))
        #expect(ContentClassifier.usesPersonDetection(for: "selfie"))
        #expect(!ContentClassifier.usesPersonDetection(for: "pizza"))
    }

    @Test("known object keywords provide broader fallback terms")
    func knownObjectKeywordsProvideFallbackTerms() {
        #expect(ContentClassifier.fallbackKeywords(for: "pizza").contains("food"))
        #expect(ContentClassifier.fallbackKeywords(for: "pizza").contains("dish"))
        #expect(ContentClassifier.fallbackKeywords(for: "dog").contains("animal"))
        #expect(ContentClassifier.fallbackKeywords(for: "unknown-object").isEmpty)
    }

    @Test("matching avoids substring false positives")
    func matchingAvoidsSubstringFalsePositives() {
        #expect(!ContentClassifier.classificationLabel("woman", matchesKeyword: "man"))
        #expect(!ContentClassifier.classificationLabel("manifest", matchesKeyword: "man"))
    }
}
