Task 1: minor (deferred): out-of-order observations move lastSeen backwards (use max); same-at sort ties nondeterministic (tie-break on label); no boundary tests (30 s, 0.6).
Task 3: minor (deferred): analysis queue has no backpressure over 8 h (low risk at 8192 frames); live engine path needs a manual device run (overnight, lock screen, interruption, route change).
Task 4: minor (deferred): second concurrent start() returns silently; late callback after pause/resume of same session passes the id check (harmless).
Task 5: minor (deferred): player request arriving while a sound session cover is up (no current route can do it); Pause/Resume swap has no focus management.
Task 6: minor (deferred): afternoon events today create a future-dated tomorrow row; no way to reset a correction to none / current correction not shown in the menu; snoring note stays until dismissed (not auto-marked shown on first display).
Final: minor (parked): manual device test plan required before release (call while locked, Siri, alarm, Bluetooth route change, 8 h on charge); -fake-sound in release builds (Plan 7 #if DEBUG); Plan 5 owner switch must stop an active session and rebuild store+sound; checkmark for current correction in menu.
Final: minor (parked): GeometryReader body not re-indented; controller's suspend() after detector teardown is a harmless no-op.
