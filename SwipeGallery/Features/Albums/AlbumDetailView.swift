import SwiftUI

/// Dentro un album: stesso comportamento della Galleria, limitato agli
/// elementi dell'album. Le decisioni restano globali.
struct AlbumDetailView: View {
    let album: AlbumSummary

    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @State private var model: AssetBrowserModel?

    var body: some View {
        Group {
            if let model {
                AssetBrowserView(model: model, albumTitle: album.title)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil {
                model = AssetBrowserModel(scope: .album(album.collection), library: library, store: store)
            }
        }
    }
}
