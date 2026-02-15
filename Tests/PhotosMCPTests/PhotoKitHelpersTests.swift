import Testing
@testable import PhotosMCP

struct PhotoKitHelpersTests {

    @Test("encodeToJSON produces valid JSON")
    func encodeToJSON() throws {
        let response = PhotoKitHelpers.SearchResponse(
            assets: [],
            total: 0,
            limit: 50,
            offset: 0
        )
        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("\"assets\""))
        #expect(json.contains("\"total\""))
        #expect(json.contains("\"limit\""))
        #expect(json.contains("\"offset\""))
        #expect(json.contains("\"total\" : 0"))
    }

    @Test("encodeToJSON with asset metadata")
    func encodeToJSONWithAssets() throws {
        let asset = PhotoKitHelpers.AssetMetadata(
            identifier: "test-id",
            creationDate: "2024-01-01T00:00:00Z",
            modificationDate: nil,
            mediaType: "photo",
            mediaSubtypes: ["none"],
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: nil,
            isFavorite: false,
            isHidden: false,
            location: .init(latitude: 40.0, longitude: -74.0),
            resourceFileSizes: nil
        )
        let response = PhotoKitHelpers.SearchResponse(
            assets: [asset],
            total: 1,
            limit: 50,
            offset: 0
        )
        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("test-id"))
        #expect(json.contains("photo"))
        #expect(json.contains("1920"))
        #expect(json.contains("1080"))
    }
}
