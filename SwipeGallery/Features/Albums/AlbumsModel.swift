import Foundation
import Observation

/// Elenco degli album con i conteggi, calcolato in background.
@MainActor
@Observable
final class AlbumsModel {
    private(set) var userAlbums: [AlbumSummary] = []
    private(set) var smartAlbums: [AlbumSummary] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    func reload(library: PhotoLibraryService, store: DecisionStore) {
        guard library.hasAccess else { return }
        loadTask?.cancel()
        isLoading = true
        let includeVideos = library.includeVideos
        let decisions = store.index
        loadTask = Task { [weak self] in
            let summaries = await Task.detached(priority: .userInitiated) {
                AlbumCatalog.loadSummaries(includeVideos: includeVideos, decisions: decisions)
            }.value
            guard !Task.isCancelled, let self else { return }
            let user = summaries.filter { $0.kind == .user }
            let smart = summaries.filter { $0.kind == .smart }
            if user != userAlbums { userAlbums = user }
            if smart != smartAlbums { smartAlbums = smart }
            isLoading = false
            hasLoaded = true
        }
    }
}
