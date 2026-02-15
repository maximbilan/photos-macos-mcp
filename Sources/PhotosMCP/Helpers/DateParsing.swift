import Foundation

/// Flexible date parsing for search parameters.
enum DateParsing {

    /// Parse date string. Supports:
    /// - "2024-01-01T00:00:00Z" (ISO 8601)
    /// - "2024-01-01" (date only, interpreted as start of day UTC)
    static func parse(_ string: String) -> Date? {
        let s = string.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        iso.timeZone = TimeZone(identifier: "UTC")
        if let d = iso.date(from: s) { return d }

        // Try without fractional seconds (e.g. "2024-01-15T14:30:00Z")
        iso.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let d = iso.date(from: s) { return d }

        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        return dateOnly.date(from: s)
    }

    /// Parse end date - for "2024-01-01" returns 23:59:59.999 of that day.
    static func parseEndOfDay(_ string: String) -> Date? {
        guard let d = parse(string) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: d)?
            .addingTimeInterval(0.999)
    }
}
