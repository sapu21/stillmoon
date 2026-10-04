Task 6: minor (deferred): Last-night card says the source twice ("Apple Watch estimate" pill and "Apple Watch estimated 7 h 20 m asleep"); consider dropping the pill when the line already names the source.
Task 6: minor (deferred): weekly-moon pill on Today is informational, not a link to Journey (spec updated); revisit if users try to tap it.
Task 9: minor (deferred): SignUpView not visually verified (ImageRenderer cannot draw its ScrollView and it has no route yet); check it when Plan 5 wires it into onboarding.
Task 10: minor (deferred): manual Reduce Motion and VoiceOver passes not run (motion rules are unit-tested; night mode, night completion and the largest text size were checked with simulator screenshots).
Task 10: minor (deferred): at the largest text sizes onboarding buttons sit below the fold and need a scroll; consider pinning the primary button.
Final: minor (deferred): speech bubble spring overshoots slightly at night (check-in via "Show everything", onboarding); use easeOut when theme.isNight.
Final: minor (deferred): completion re-pops the last moon when the week was already full (4th of 3); animate only when windDownsThisWeek <= weeklyGoal.
Final: minor (deferred): Lumi, StarField and lit-star effects keep drawing while scrolled off-screen in non-lazy ScrollViews (Journey, Today); consider LazyVStack or visibility-based pausing.
Final: minor (deferred): next-star button does nothing if the catalog has no wind-down; disable it when nextTitle is nil.
Final: minor (deferred): Journey ring "3/3" label can clip at accessibility sizes; hide from VoiceOver and add minimumScaleFactor.
Final: minor (deferred): player Lumi and rings keep breathing while paused; pass animated: model.isPlaying.
