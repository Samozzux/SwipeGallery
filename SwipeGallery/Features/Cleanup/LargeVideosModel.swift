import Foundation
import Observation
import Photos

/// Un video con la sua dimensione su disco (se disponibile).
struct VideoEntry: Identifiable, Equatable, Sendable {
    let asset: PHAsset
    let bytes: Int64?

    var id: String { asset.localIdentifier }
}

/// Tutti i video della libreria, dal più pesante.
@MainActor
@Observable
final class LargeVideosModel {
    private(set) var entries: [VideoEntry] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadedChangeCount: Int?

    var totalBytes: Int64 {
        entries.reduce(0) { $0 + ($1.bytes ?? 0) }
    }

    func reloadIfNeeded(library: PhotoLibraryService) {
        guard library.hasAccess, loadedChangeCount != library.changeCount else { return }
        loadedChangeCount = library.changeCount
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            let entries = await Task.detached(priority: .userInitiated) {
                Self.loadEntries()
            }.value
            guard !Task.isCancelled else { return }
            self.entries = entries
            isLoading = false
            hasLoaded = true
        }
    }

    /// Legge le dimensioni di ogni video: chiamate sincrone, fuori dal main thread.
    nonisolated private static func loadEntries() -> [VideoEntry] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videos = PHAsset.fetchAssets(with: .video, options: options)
        var entries: [VideoEntry] = []
        entries.reserveCapacity(videos.count)
        for index in 0 ..< videos.count {
            if Task.isCancelled { break }
            let asset = videos.object(at: index)
            entries.append(VideoEntry(asset: asset, bytes: AssetFileSize.bytes(of: asset)))
        }
        // Senza dimensione in fondo; a parità, il più lungo prima.
        return entries.sorted { lhs, rhs in
            let left = lhs.bytes ?? -1
            let right = rhs.bytes ?? -1
            return left != right ? left > right : lhs.asset.duration > rhs.asset.duration
        }
    }
}
