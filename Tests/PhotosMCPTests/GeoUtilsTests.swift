import Testing
@testable import PhotosMCP

struct GeoUtilsTests {

    @Test("haversine same point returns zero")
    func haversineSamePoint() {
        let d = GeoUtils.haversineKm(lat1: 40.0, lon1: -74.0, lat2: 40.0, lon2: -74.0)
        #expect(d < 0.001)  // essentially zero
    }

    @Test("haversine known distance")
    func haversineKnownDistance() {
        // New York (40.7128, -74.0060) to Philadelphia (~129 km)
        let nyLat = 40.7128
        let nyLon = -74.0060
        let phillyLat = 39.9526
        let phillyLon = -75.1652
        let d = GeoUtils.haversineKm(lat1: nyLat, lon1: nyLon, lat2: phillyLat, lon2: phillyLon)
        #expect(d > 120 && d < 140)
    }

    @Test("haversine antipodal points ~20000 km")
    func haversineAntipodal() {
        // Opposite sides of Earth
        let d = GeoUtils.haversineKm(lat1: 0, lon1: 0, lat2: 0, lon2: 180)
        #expect(d > 19900 && d < 20100)
    }
}
