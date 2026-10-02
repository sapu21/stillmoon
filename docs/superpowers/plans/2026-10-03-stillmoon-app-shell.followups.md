Task 2: minor (deferred): LocalStore swallows fetch/save errors in release (assertionFailure only) — add logging before Plan 5.
Task 2: minor (deferred): SavedItemRecord duplicates possible after CloudKit merge (Plan 7 must reconcile by itemID).
Task 2: minor (deferred): JournalEntry.asleepMinutes is time in bed — doc comment / rename.
Task 3: minor (deferred): ClockTime.date(on:) force-unwrap can fail in DST-gap zones; add `?? day` fallback.
Task 4: minor (deferred): catalog load failure silently gives empty content (log/assert); placeholder copy and licence wording revisited in Plan 6.
Task 5: minor (deferred): validation message uses .red only; DatePickers allow future dates (validation covers order/length only).
Task 6: minor (deferred): tick timer drifts (loop-count based, not wall clock); VoiceOver doesn't announce step changes; skip button only 44pt; ArticleView ForEach id by url; detail views save with .now and duplicate ExercisesModel save logic; LocalizedStringKey renders stray markdown.
Task 7: minor (deferred): no acknowledgement after delete; delete test doesn't assert goal/hideProgress reset; Recently rows not grouped for VoiceOver.
Task 8: minor (deferred): showEverythingAtNight never resets; redundant todayCheckIn lookup; dropped recs give no signal; no boundary tests for 20h window / greeting cutoffs.
Task 9: minor (deferred): onboarding back after Continue keeps saved schedule; tint applied twice.
Final: minor (parked): review date shown raw; TimelineView rebuilds MainTabs init each minute (State keeps first); todayCheckIn not refreshed at midnight while foregrounded; fatalError on store open needs Plan 7 recovery; "stay on this iPhone" copy must change in Plan 7.
Final: minor (parked): wind-down "Start" button lacks exercise name for VoiceOver; card title not header; nightPhase .windDown when forced on early evening.
