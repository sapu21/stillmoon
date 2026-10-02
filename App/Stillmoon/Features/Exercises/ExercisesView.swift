import SwiftUI
import StillmoonCore

struct ExercisesView: View {
    @Environment(\.theme) private var theme
    @Bindable var model: ExercisesModel

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", .all)
                        ForEach(ExerciseCategory.allCases, id: \.self) { chip($0.title, .category($0)) }
                        chip("Saved", .saved)
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if !model.exercises.isEmpty {
                Section("Exercises") {
                    ForEach(model.exercises) { exercise in
                        NavigationLink(value: Route.exercise(exercise.id)) {
                            ExerciseRow(exercise: exercise, isSaved: model.isSaved(exercise.id))
                        }
                        .listRowBackground(theme.surface)
                    }
                }
            }
            if !model.articles.isEmpty {
                Section("Articles") {
                    ForEach(model.articles) { article in
                        NavigationLink(value: Route.article(article.id)) {
                            ArticleRow(article: article)
                        }
                        .listRowBackground(theme.surface)
                    }
                }
            }
            if model.exercises.isEmpty && model.articles.isEmpty {
                ContentUnavailableView.search(text: model.query)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .searchable(text: $model.query, prompt: "Search exercises and articles")
        .navigationTitle("Exercises")
        .onAppear { model.refresh() }
    }

    private func chip(_ title: String, _ filter: LibraryFilter) -> some View {
        Button(title) { model.filter = filter }
            .buttonStyle(.bordered)
            .tint(model.filter == filter ? theme.accent : theme.secondaryText)
            .accessibilityAddTraits(model.filter == filter ? .isSelected : [])
    }
}

struct ExerciseRow: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let isSaved: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.title).font(.headline)
                Text("\(exercise.category.title) · \(Format.exerciseLength(seconds: exercise.durationSeconds)) · \(exercise.format == .audio ? "Audio" : "Text")")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel("Saved")
            }
        }
        .foregroundStyle(theme.text)
    }
}

struct ArticleRow: View {
    @Environment(\.theme) private var theme
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title).font(.headline)
            Text(article.summary)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(theme.secondaryText)
            Text("Reviewed \(article.reviewedOn)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .foregroundStyle(theme.text)
    }
}
