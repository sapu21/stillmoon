import Foundation
import SwiftData
import StillmoonCore
@testable import Stillmoon

enum TestEnv {
    static let tz = TimeZone(identifier: "America/New_York")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1
        return c
    }

    static func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }

    static func container() throws -> ModelContainer {
        try StillmoonSchema.makeContainer(inMemory: true)
    }

    static func store(owner: String = "user-a", container: ModelContainer? = nil) throws -> LocalStore {
        LocalStore(container: try container ?? Self.container(), ownerID: owner)
    }
}
