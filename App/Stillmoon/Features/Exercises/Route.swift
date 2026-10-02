import SwiftUI

enum Route: Hashable {
    case exercise(String)
    case article(String)
}

struct RouteDestination: View {
    @Environment(AppEnvironment.self) private var env
    let route: Route

    var body: some View {
        switch route {
        case .exercise(let id):
            if let exercise = env.catalog.exercise(id: id) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView("Not available", systemImage: "questionmark.circle")
            }
        case .article(let id):
            if let article = env.catalog.article(id: id) {
                ArticleView(article: article)
            } else {
                ContentUnavailableView("Not available", systemImage: "questionmark.circle")
            }
        }
    }
}
