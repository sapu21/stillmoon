import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let exercise: Exercise
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.title)
                    .font(.largeTitle.weight(.semibold))
                Text("\(exercise.category.title) · \(Format.exerciseLength(seconds: exercise.durationSeconds))")
                    .foregroundStyle(theme.secondaryText)
                Text(exercise.summary)
                Button {
                    env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
                Text("Based on: \(exercise.techniqueSource)")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    env.store.setSaved(exercise.id, !isSaved, at: .now)
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
            }
        }
        .onAppear { isSaved = env.store.savedItemIDs().contains(exercise.id) }
    }
}
