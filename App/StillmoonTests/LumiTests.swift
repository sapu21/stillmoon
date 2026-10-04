import Testing
@testable import Stillmoon

struct LumiTests {
    @Test func reduceMotionStopsEverything() {
        for motion in [LumiMotion.float, .drift, .bounce, .still, .breathe(period: 8)] {
            #expect(motion.effective(reduceMotion: true, isNight: false) == .still)
            #expect(motion.effective(reduceMotion: true, isNight: true) == .still)
        }
    }

    @Test func neverBouncesOrCheersAtNight() {
        #expect(LumiMotion.bounce.effective(reduceMotion: false, isNight: true) == .drift)
        #expect(LumiMotion.bounce.effective(reduceMotion: false, isNight: false) == .bounce)
        #expect(LumiMood.cheer.effective(isNight: true) == .happy)
        #expect(LumiMood.cheer.effective(isNight: false) == .cheer)
        for mood in LumiMood.allCases {
            #expect(!LumiPose.of(mood.effective(isNight: true)).sparkles)
        }
    }

    @Test func posesMatchTheCharacterSheet() {
        #expect(LumiPose.of(.cheer).leftArmUp && LumiPose.of(.cheer).rightArmUp)
        #expect(LumiPose.of(.wave).rightArmUp && !LumiPose.of(.wave).leftArmUp)
        #expect(LumiPose.of(.sleepy).zzz && LumiPose.of(.sleepy).eyes == .sleepy)
        #expect(LumiPose.of(.concerned).brows && LumiPose.of(.concerned).mouth == .wobble)
        #expect(LumiMood.allCases.filter { LumiPose.of($0).sparkles } == [.cheer])
    }

    @Test func motionCurves() {
        #expect(LumiAnimation.transform(.still, at: 3) == LumiAnimation.Transform())
        #expect(abs(LumiAnimation.transform(.float, at: 2).dy + 7) < 0.001) // top of the float halfway through 4 s
        let exhaled = LumiAnimation.transform(.breathe(period: 8), at: 0)
        let inhaled = LumiAnimation.transform(.breathe(period: 8), at: 4)
        #expect(abs(exhaled.scaleX - 0.92) < 0.001)
        #expect(abs(inhaled.scaleX - 1.06) < 0.001)
        let hops = stride(from: 0.0, to: 1.6, by: 0.05).map { LumiAnimation.transform(.bounce, at: $0).dy }
        #expect(hops.allSatisfy { $0 <= 0 && $0 >= -18 })
    }

    @Test func blinksBriefly() {
        #expect(LumiAnimation.eyeScale(at: 0) == 1)
        #expect(LumiAnimation.eyeScale(at: 4.8) < 0.5) // 96% through the 5 s cycle
        let closed = stride(from: 0.0, to: 5.0, by: 0.01).filter { LumiAnimation.eyeScale(at: $0) < 0.5 }.count
        #expect(closed < 30) // eyes shut for well under a third of a second
    }
}
