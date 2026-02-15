import Foundation
import Testing
@testable import PhotosMCP

struct DateParsingTests {

    @Test("parse ISO 8601 datetime")
    func parseISO8601() {
        let d = DateParsing.parse("2024-01-15T14:30:00Z")
        #expect(d != nil)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = cal.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: d!
        )
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    @Test("parse date-only yyyy-MM-dd")
    func parseDateOnly() {
        let d = DateParsing.parse("2024-06-20")
        #expect(d != nil)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = cal.dateComponents(
            [.year, .month, .day],
            from: d!
        )
        #expect(components.year == 2024)
        #expect(components.month == 6)
        #expect(components.day == 20)
    }

    @Test("parse empty string returns nil")
    func parseEmpty() {
        #expect(DateParsing.parse("") == nil)
        #expect(DateParsing.parse("   ") == nil)
    }

    @Test("parse invalid string returns nil")
    func parseInvalid() {
        #expect(DateParsing.parse("not-a-date") == nil)
        #expect(DateParsing.parse("invalid") == nil)
    }

    @Test("parseEndOfDay returns end of same day")
    func parseEndOfDay() {
        let d = DateParsing.parseEndOfDay("2024-01-15")
        #expect(d != nil)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: d!
        )
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
        #expect(components.second == 59)
    }

    @Test("parseEndOfDay with invalid string returns nil")
    func parseEndOfDayInvalid() {
        #expect(DateParsing.parseEndOfDay("") == nil)
        #expect(DateParsing.parseEndOfDay("invalid") == nil)
    }
}
