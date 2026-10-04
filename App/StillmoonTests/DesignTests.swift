import Testing
@testable import Stillmoon

struct DesignTests {
    @Test func moonPhaseGoesFromNewToFull() {
        let offsets = (1...5).map { MoonPhase.shadowOffset(level: $0) }
        #expect(offsets == offsets.sorted())
        #expect(MoonPhase.shadowOffset(level: 1) == 0)
        #expect(MoonPhase.shadowOffset(level: 5) >= 2) // shadow fully clear of the moon
        #expect(MoonPhase.shadowOffset(level: 0) == MoonPhase.shadowOffset(level: 1))
        #expect(MoonPhase.shadowOffset(level: 9) == MoonPhase.shadowOffset(level: 5))
    }

    @Test func restednessLabels() {
        #expect((1...5).map(MoonPhase.label(level:)) == ["Not rested", "A little rested", "Okay", "Rested", "Very rested"])
    }

    @Test func weekMoonFillsWithProgress() {
        #expect(MoonPhase.level(done: 0, goal: 3) == 1)
        #expect(MoonPhase.level(done: 1, goal: 3) == 2)
        #expect(MoonPhase.level(done: 2, goal: 3) == 3)
        #expect(MoonPhase.level(done: 3, goal: 3) == 5)
        #expect(MoonPhase.level(done: 5, goal: 3) == 5)
        #expect(MoonPhase.level(done: 1, goal: 0) == 5) // goal floors at 1
    }
}
