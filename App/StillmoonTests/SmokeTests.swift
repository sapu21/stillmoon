import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SmokeTests {
    @Test func coreIsLinked() {
        #expect(NightModeResolver.defaultBedtime.hour == 22)
    }
}
