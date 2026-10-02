import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        // Re-evaluates night mode every minute (PRD §7).
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let night = env.settings.isNight(at: context.date, calendar: .current, sessionActive: env.sessionActive)
            let theme: Theme = night ? .night : .day
            Group {
                if env.settings.settings.hasOnboarded {
                    MainTabs(env: env)
                } else {
                    OnboardingView(settings: env.settings)
                }
            }
            .environment(\.theme, theme)
            .tint(theme.accent)
            .preferredColorScheme(night ? .dark : .light)
        }
    }
}

struct MainTabs: View {
    @Environment(AppEnvironment.self) private var env
    @State private var today: TodayModel
    @State private var sleep: SleepModel
    @State private var exercises: ExercisesModel
    @State private var journey: JourneyModel

    init(env: AppEnvironment) {
        _today = State(initialValue: TodayModel(store: env.store, settings: env.settings, catalog: env.catalog, health: env.health))
        _sleep = State(initialValue: SleepModel(store: env.store, health: env.health, settings: env.settings))
        _exercises = State(initialValue: ExercisesModel(store: env.store, catalog: env.catalog))
        _journey = State(initialValue: JourneyModel(store: env.store, settings: env.settings, catalog: env.catalog))
    }

    var body: some View {
        @Bindable var env = env
        TabView {
            NavigationStack {
                TodayView(model: today)
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tabItem { Label("Today", systemImage: "sun.horizon") }

            NavigationStack {
                SleepView(model: sleep)
            }
            .tabItem { Label("Sleep", systemImage: "bed.double") }

            NavigationStack {
                ExercisesView(model: exercises)
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tabItem { Label("Exercises", systemImage: "leaf") }

            NavigationStack {
                JourneyView(model: journey)
            }
            .tabItem { Label("Journey", systemImage: "map") }
        }
        .fullScreenCover(item: $env.playerRequest, onDismiss: {
            Task { await today.refreshHealth() }
            journey.refresh()
        }) { request in
            if let exercise = env.catalog.exercise(id: request.exerciseID) {
                PlayerView(exercise: exercise, store: env.store) { interval in
                    guard env.settings.settings.healthConnected else { return }
                    Task { try? await env.health.saveMindfulSession(start: interval.start, end: interval.end) }
                }
            } else {
                ContentUnavailableView("This exercise isn't available", systemImage: "questionmark.circle")
                    .overlay(alignment: .bottom) {
                        Button("Close") { env.playerRequest = nil }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.bottom, 48)
                    }
            }
        }
    }
}
