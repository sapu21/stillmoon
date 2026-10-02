import SwiftUI
import StillmoonCore

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let model: TodayModel
    @State private var showingCheckIn = false
    @State private var showingJournal = false
    @State private var showingSettings = false
    @State private var showEverythingAtNight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.greeting)
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityIdentifier("greeting")
                if theme.isNight && !showEverythingAtNight {
                    nightContent
                } else {
                    dayContent
                }
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "person.crop.circle") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingCheckIn, onDismiss: model.refresh) {
            CheckInSheet(existing: model.todayCheckIn) { model.saveCheckIn($0) }
        }
        .sheet(isPresented: $showingJournal, onDismiss: model.refresh) {
            JournalEntryForm { model.saveJournalEntry($0) }
        }
        .sheet(isPresented: $showingSettings, onDismiss: model.refresh) {
            SettingsView()
        }
        .onAppear { model.refresh() }
    }

    // MARK: Night: one card, large controls, nothing to track (PRD §7).

    @ViewBuilder private var nightContent: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Awake at night?").font(.title2.weight(.semibold))
                Text("A few quiet minutes can help you settle. There's nothing to track.")
                    .foregroundStyle(theme.secondaryText)
                if let exercise = model.awakeAtNightExercise {
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                    } label: {
                        Label(exercise.title, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.accent)
                }
            }
        }
        Button("Show everything") { showEverythingAtNight = true }
            .font(.footnote)
            .foregroundStyle(theme.secondaryText)
    }

    // MARK: Day

    @ViewBuilder private var dayContent: some View {
        lastNightCard
        checkInCard
        if model.showsDifficultyCard {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If sleep has been hard for weeks, it can help to talk with a doctor.")
                    NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                }
            }
        }
        if let first = model.recommendations.first {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Suggested for you").font(.caption).foregroundStyle(theme.secondaryText)
                        Spacer()
                        feedbackMenu(first.itemID)
                    }
                    NavigationLink(value: first.route) {
                        Text(first.title).font(.title3.weight(.semibold))
                    }
                    Text(first.reason).font(.subheadline).foregroundStyle(theme.secondaryText)
                }
            }
        }
        if model.recommendations.count > 1 {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Also for you").font(.headline)
                    ForEach(model.recommendations.dropFirst()) { rec in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                NavigationLink(rec.title, value: rec.route)
                                Text(rec.reason).font(.caption).foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            feedbackMenu(rec.itemID)
                        }
                    }
                }
            }
        }
        if !model.hideProgress {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This week").font(.headline)
                    Text("\(model.progress.windDownsThisWeek) of \(model.progress.weeklyGoal) wind-downs")
                    ProgressView(value: Double(min(model.progress.windDownsThisWeek, model.progress.weeklyGoal)),
                                 total: Double(model.progress.weeklyGoal))
                        .tint(theme.accent)
                }
            }
        }
    }

    @ViewBuilder private var lastNightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last night").font(.headline)
                if let entry = model.lastNight {
                    Text("You recorded \(Format.duration(minutes: entry.asleepMinutes)) in bed")
                        .font(.title3)
                    Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text("Nothing recorded for last night yet.")
                        .foregroundStyle(theme.secondaryText)
                    Button("Add last night") { showingJournal = true }
                }
            }
        }
    }

    @ViewBuilder private var checkInCard: some View {
        Card {
            if let checkIn = model.todayCheckIn {
                HStack {
                    Text("You felt \(checkIn.restedness) of 5 rested")
                    Spacer()
                    Button("Edit") { showingCheckIn = true }
                }
            } else {
                Button { showingCheckIn = true } label: {
                    Label("How do you feel?", systemImage: "sun.haze")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func feedbackMenu(_ itemID: String) -> some View {
        Menu {
            Button("Helpful") { model.rate(itemID, .helpful) }
            Button("Not relevant") { model.rate(itemID, .irrelevant) }
            Button("Don't show this again", role: .destructive) { model.rate(itemID, .unwanted) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Rate this suggestion")
    }
}
