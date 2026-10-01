import Foundation
import Testing
@testable import StillmoonCore

struct ExportTests {
    let checkIn = CheckIn(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                          date: T.d(2026, 10, 2, 8), restedness: 4, tenseAtBedtime: true,
                          note: "Slept \"ok\", woke at 3\nthen read")

    var bundle: ExportBundle {
        ExportBundle(
            exportedAt: T.d(2026, 10, 2, 9),
            nights: [NightExport(nightOf: T.d(2026, 10, 1), sleepStart: T.d(2026, 10, 1, 23),
                                 sleepEnd: T.d(2026, 10, 2, 6, 30), asleepMinutes: 440,
                                 primarySource: "Apple Watch",
                                 samples: [SleepSample(stage: .core, start: T.d(2026, 10, 1, 23),
                                                       end: T.d(2026, 10, 2, 6, 30), sourceName: "Apple Watch")])],
            checkIns: [checkIn],
            soundEvents: [SoundEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                                     label: .speechLike, at: T.d(2026, 10, 2, 2, 14), confidence: 0.61,
                                     correction: .someoneElse)],
            completions: [ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: T.d(2026, 10, 1, 22))],
            feedback: [RecommendationFeedback(itemID: "breath", rating: .helpful, at: T.d(2026, 10, 2, 8))]
        )
    }

    @Test func jsonRoundTrips() throws {
        let original = bundle // computed once: it mints random UUIDs
        let data = try ExportWriter.json(original)
        #expect(try ExportWriter.decode(data) == original)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"exportedAt\" : \"2026-10-02T13:00:00Z\""))
    }

    @Test func checkInCSVEscapesNotes() {
        let csv = ExportWriter.checkInsCSV([checkIn])
        let expected = """
        date,restedness,tense_at_bedtime,woke_during_night,persistent_difficulty,note
        2026-10-02T12:00:00Z,4,true,false,false,"Slept ""ok"", woke at 3
        then read"

        """
        #expect(csv == expected)
    }

    @Test func soundEventsCSV() {
        let csv = ExportWriter.soundEventsCSV(bundle.soundEvents)
        #expect(csv == "time,label,confidence,correction\n2026-10-02T06:14:00Z,speechLike,0.61,someoneElse\n")
    }

    @Test func nightsCSV() {
        let csv = ExportWriter.nightsCSV(bundle.nights)
        #expect(csv == "night_of,sleep_start,sleep_end,asleep_minutes,source\n2026-10-01T04:00:00Z,2026-10-02T03:00:00Z,2026-10-02T10:30:00Z,440,Apple Watch\n")
    }

    @Test func emptyCSVHasHeaderOnly() {
        #expect(ExportWriter.soundEventsCSV([]) == "time,label,confidence,correction\n")
    }

    @Test(arguments: [("plain", "plain"), ("a,b", "\"a,b\""), ("say \"hi\"", "\"say \"\"hi\"\"\""), ("line\rbreak", "\"line\rbreak\""), ("a\r\nb", "\"a\r\nb\"")])
    func fieldEscaping(input: String, output: String) {
        #expect(ExportWriter.field(input) == output)
    }
}
