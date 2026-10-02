import SwiftUI

struct ArticleView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let article: Article
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.largeTitle.weight(.semibold))
                Text(article.summary)
                    .font(.title3)
                    .foregroundStyle(theme.secondaryText)
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(LocalizedStringKey(paragraph))
                }
                Divider()
                Text("Sources").font(.headline)
                ForEach(article.sources, id: \.url) { source in
                    Link(source.title, destination: source.url)
                }
                Text("Reviewed \(article.reviewedOn)")
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
                    env.store.setSaved(article.id, !isSaved, at: .now)
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
            }
        }
        .onAppear { isSaved = env.store.savedItemIDs().contains(article.id) }
    }
}
