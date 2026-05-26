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

    @Test("matching avoids substring false positives")
    func matchingAvoidsSubstringFalsePositives() {
        #expect(!ContentClassifier.classificationLabel("woman", matchesKeyword: "man"))
        #expect(!ContentClassifier.classificationLabel("manifest", matchesKeyword: "man"))
    }
}
