import SwiftUI
import StillmoonCore

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: TodayModel
    @State private var showingCheckIn = false
    @State private var checkInLevel: Int?
    @State private var showingJournal = false
    @State private var showingSettings = false
    @State private var showEverythingAtNight = false

    var body: some View {
        ScrollView {
            if theme.isNight && !showEverythingAtNight {
                nightContent
            } else {
                VStack(spacing: 0) {
                    header
                    dayContent
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(theme.background,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                        .padding(.top, -28)
                }
            }
        }
        .foregroundStyle(theme.text)
        .background(alignment: .top) { theme.sky.frame(height: 400).ignoresSafeArea() }
        .background(theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCheckIn, onDismiss: model.refresh) {
            CheckInSheet(existing: model.todayCheckIn, initialLevel: checkInLevel) { model.saveCheckIn($0) }
        }
        .sheet(isPresented: $showingJournal, onDismiss: model.refresh) {
            JournalEntryForm { model.saveJournalEntry($0) }
        }
        .sheet(isPresented: $showingSettings, onDismiss: { Task { await model.refreshHealth() } }) {
            SettingsView()
        }
        .task { await model.refreshHealth() }
        .onChange(of: theme.isNight) { _, _ in showEverythingAtNight = false }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refreshHealth() } } }
    }

    // MARK: Shared pieces

    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "person.fill")
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(theme.surface, in: Circle())
        }
        .accessibilityLabel("Settings")
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.greeting)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("greeting")
                .accessibilityAddTraits(.isHeader)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var showsSoundStart: Bool {
        env.sound.isAvailable && !env.sound.isActive && env.playerRequest == nil
    }

    // MARK: Night: one card, large controls, nothing to track (PRD §7).

    @ViewBuilder private var nightContent: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.greeting)
                        .font(.title.weight(.semibold))
                        .accessibilityIdentifier("greeting")
                        .accessibilityAddTraits(.isHeader)
                    Text("Night mode is on")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                settingsButton
            }
            VStack(spacing: 0) {
                LumiView(mood: .sleepy, motion: .drift, size: 150)
                Cloud().fill(theme.surface).frame(width: 200, height: 40).padding(.top, -30)
                    .accessibilityHidden(true)
            }
            switch model.nightPhase(at: .now) {
            case .windDown: windDownCard
            case .awake: awakeCard
            }
            Button("Show everything") { showEverythingAtNight = true }
                .font(.headline)
                .frame(minHeight: 44)
        }
        .padding(20)
        .background(alignment: .top) {
            StarField(stars: StarField.night, color: Color(hex: 0xCFC6EE), period: 6, alphaRange: 0.15...0.6)
                .frame(height: 420)
        }
    }

    @ViewBuilder private var windDownCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Time to wind down").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                if let suggestion = model.windDownSuggestion {
                    Text(suggestion.title).font(.title3.weight(.bold))
                    if !suggestion.reason.isEmpty {
                        Text(suggestion.reason).foregroundStyle(theme.secondaryText)
                    }
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: suggestion.itemID)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .accessibilityLabel("Start \(suggestion.title)")
                } else {
                    Text("Dim the lights and breathe out slowly. Resting is enough.")
                }
                if showsSoundStart { SoundStartButton() }
            }
        }
    }

    @ViewBuilder private var awakeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Awake at night?").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("A few quiet minutes can help you settle. There's nothing to track.")
                    .foregroundStyle(theme.secondaryText)
                if let exercise = model.awakeAtNightExercise {
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                    } label: {
                        Label(exercise.title, systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                } else {
                    Text("Breathe out slowly, a little longer than you breathe in. Resting is enough.")
                }
            }
        }
    }

    // MARK: Day

    private var header: some View {
        let line = LumiDirector.todayHeader(progress: model.progress, hideProgress: model.hideProgress, isNight: theme.isNight)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !model.hideProgress { WeekPill(progress: model.progress) }
                Spacer()
                settingsButton
            }
            if dynamicTypeSize.isAccessibilitySize {
                greetingBlock
                if let text = line.text { SpeechBubble(text: text) }
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 14) {
                        greetingBlock
                        if let text = line.text { SpeechBubble(text: text, tail: .trailing) }
                    }
                    Spacer(minLength: 0)
                    LumiView(mood: line.mood, motion: line.motion, size: 130)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 44)
        .background { SkyBackdrop().ignoresSafeArea(edges: .top) }
    }

    @ViewBuilder private var dayContent: some View {
        VStack(spacing: 14) {
            checkInCard.riseIn()
            lastNightCard.riseIn(delay: 0.08)
            if model.showsDifficultyCard {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If sleep has been hard for weeks, it can help to talk with a doctor.")
                        NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                            .font(.headline)
                    }
                }
            }
            if model.showsSnoringNote {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequent loud snoring is worth mentioning to a doctor.")
                        NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                            .font(.headline)
                        Button("Dismiss") { model.dismissSnoringNote() }
                    }
                }
            }
            if let first = model.recommendations.first {
                suggestionCard(first).riseIn(delay: 0.16)
            }
            if model.recommendations.count > 1 {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Also for you").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(model.recommendations.dropFirst()) { rec in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    NavigationLink(rec.title, value: rec.route).font(.headline)
                                    Text(rec.reason).font(.caption).foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                                feedbackMenu(rec.itemID, title: rec.title)
                            }
                        }
                    }
                }
            }
            if showsSoundStart { SoundStartButton() }
        }
    }

    @ViewBuilder private var checkInCard: some View {
        Card {
            if let checkIn = model.todayCheckIn {
                HStack(spacing: 12) {
                    MoonPhaseView(level: checkIn.restedness, background: theme.surface, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You checked in: \(MoonPhase.label(level: checkIn.restedness))").font(.headline)
                        Text("Kept apart from your watch's estimates")
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Button("Edit") {
                        checkInLevel = nil
                        showingCheckIn = true
                    }
                    .font(.headline)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How rested do you feel?").font(.headline).accessibilityAddTraits(.isHeader)
                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { level in
                            MoonButton(level: level, isSelected: false, size: 54) {
                                checkInLevel = level
                                showingCheckIn = true
                            }
                            if level < 5 { Spacer(minLength: 4) }
                        }
                    }
                    HStack {
                        Text("Not rested")
                        Spacer()
                        Text("Very rested")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder private var lastNightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last night").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let report = model.lastNightReport {
                        LabelPill(text: "\(report.primarySource) estimate")
                    } else if model.lastNight != nil {
                        LabelPill(text: "You recorded")
                    }
                }
                if let report = model.lastNightReport {
                    Text(NightSummary.estimateLine(report)).font(.title3.weight(.semibold))
                    Text("\(report.sleepStart.formatted(date: .omitted, time: .shortened)) to \(report.sleepEnd.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                    if report.hasStageDetail { StageBar(timeline: report.timeline) }
                    if let entry = model.lastNight {
                        Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                            .foregroundStyle(theme.secondaryText)
                    }
                } else if let entry = model.lastNight {
                    Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                        .font(.title3.weight(.semibold))
                    Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text("Nothing recorded for last night yet.")
                        .foregroundStyle(theme.secondaryText)
                    Button("Add last night") { showingJournal = true }
                        .font(.headline)
                }
            }
        }
    }

    private func suggestionCard(_ rec: ResolvedRecommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconTile(systemName: rec.kind == .exercise ? "wind" : "book.closed")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested for you")
                            .font(.caption.weight(.heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(theme.secondaryText)
                        NavigationLink(value: rec.route) {
                            Text(rec.title).font(.headline).multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(theme.text)
                        if let meta = model.meta(for: rec) {
                            Text(meta).font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    if rec.kind == .exercise {
                        Button {
                            env.playerRequest = PlayerRequest(exerciseID: rec.itemID)
                        } label: {
                            Image(systemName: "play.fill").font(.title3)
                        }
                        .buttonStyle(RoundChunkyButtonStyle())
                        .accessibilityLabel("Start \(rec.title)")
                    }
                }
                HStack(alignment: .top) {
                    ReasonLine(reason: rec.reason)
                    feedbackMenu(rec.itemID, title: rec.title)
                }
            }
        }
    }

    private func feedbackMenu(_ itemID: String, title: String) -> some View {
        Menu {
            Button("Helpful") { model.rate(itemID, .helpful) }
            Button("Not relevant") { model.rate(itemID, .irrelevant) }
            Button("Don't show this again", role: .destructive) { model.rate(itemID, .unwanted) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Rate \(title)")
    }
}

/// "2 of 3 this week" with the week's moon filling up.
private struct WeekPill: View {
    @Environment(\.theme) private var theme
    let progress: ProgressSummary

    var body: some View {
        HStack(spacing: 8) {
            MoonPhaseView(level: MoonPhase.level(done: progress.windDownsThisWeek, goal: progress.weeklyGoal),
                          background: theme.surface, size: 24)
            Text("\(min(progress.windDownsThisWeek, progress.weeklyGoal)) of \(progress.weeklyGoal) this week")
                .font(.subheadline.weight(.heavy))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(minHeight: 40)
        .background(theme.surface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(min(progress.windDownsThisWeek, progress.weeklyGoal)) of \(progress.weeklyGoal) wind-downs this week")
    }
}
