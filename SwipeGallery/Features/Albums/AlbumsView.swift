import SwiftUI

/// Tab Album: griglia a 2 colonne con copertina, nome e conteggi.
struct AlbumsView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @State private var model = AlbumsModel()

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if !model.userAlbums.isEmpty {
                    section("I miei album", albums: model.userAlbums)
                }
                if !model.smartAlbums.isEmpty {
                    section("Tipi di contenuto", albums: model.smartAlbums)
                }
            }
            .overlay {
                if model.hasLoaded, model.userAlbums.isEmpty, model.smartAlbums.isEmpty {
                    ContentUnavailableView(
                        "Nessun album",
                        systemImage: "rectangle.stack",
                        description: Text("Gli album con almeno un elemento compariranno qui.")
                    )
                } else if !model.hasLoaded {
                    ProgressView()
                }
            }
            .navigationTitle("Album")
            .navigationDestination(for: AlbumSummary.self) { album in
                AlbumDetailView(album: album)
            }
            // Anche al ritorno da un album, per aggiornare i "da valutare".
            .onAppear {
                model.reload(library: library, store: store)
            }
        }
        .onChange(of: library.changeCount) {
            model.reload(library: library, store: store)
        }
    }

    private func section(_ title: String, albums: [AlbumSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumCard(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// Copertina (elemento più recente), nome e conteggi di un album.
struct AlbumCard: View {
    let album: AlbumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        if let cover = album.cover {
                            AssetThumbnail(asset: cover, side: proxy.size.width)
                        } else {
                            Rectangle().fill(.quaternary)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            Text(album.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(Formatters.items(album.totalCount))
                if album.unratedCount > 0 {
                    Text("·")
                    Text("\(Formatters.number(album.unratedCount)) da valutare")
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Tutto valutato")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
