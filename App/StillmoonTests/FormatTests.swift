import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct FormatTests {
    @Test(arguments: [(45, "45 m"), (60, "1 h"), (440, "7 h 20 m"), (0, "0 m")])
    func duration(minutes: Int, text: String) {
        #expect(Format.duration(minutes: minutes) == text)
    }

    @Test(arguments: [(300, "5 min"), (30, "1 min"), (90, "2 min"), (600, "10 min")])
    func exerciseLength(seconds: Int, text: String) {
        #expect(Format.exerciseLength(seconds: seconds) == text)
    }

    @Test(arguments: [(245, "4:05"), (0, "0:00"), (59, "0:59"), (600, "10:00")])
    func clock(seconds: Int, text: String) {
        #expect(Format.clock(seconds: seconds) == text)
    }

    @Test func displayNames() {
        #expect(ExerciseCategory.awakeAtNight.title == "Awake at Night")
        #expect(Goal.consistency.title == "Build a steady routine")
    }
}
