import Foundation
import Observation
import Photos

/// Stato del cestino interno all'app: finché non viene svuotato, nessun
/// elemento viene toccato nella Libreria Foto.
@MainActor
@Observable
final class TrashModel {
    /// Elementi nel cestino, dal più recentemente scartato.
    private(set) var assets: [PHAsset] = []
    /// Spazio stimato; `nil` se non disponibile o ancora in calcolo.
    private(set) var estimatedBytes: Int64?
    var isSelecting = false {
        didSet {
            if !isSelecting {
                selection.removeAll()
            }
        }
    }
    var selection: Set<String> = []

    @ObservationIgnored private var sizeTask: Task<Void, Never>?
    @ObservationIgnored private var loadedIDs: [String] = []

    var allIDs: [String] { assets.map(\.localIdentifier) }

    /// Rilegge gli asset del cestino. I record di elementi già eliminati fuori
    /// dall'app vengono rimossi in silenzio.
    func reload(library: PhotoLibraryService, store: DecisionStore, force: Bool = false) {
        let ids = store.index.trashedIDsByRecency
        guard force || ids != loadedIDs else { return }
        loadedIDs = ids
        let found = library.assets(withIDs: ids)
        assets = found
        selection.formIntersection(Set(found.map(\.localIdentifier)))

        if found.count < ids.count, library.authorization == .authorized {
            let foundIDs = Set(found.map(\.localIdentifier))
            let missing = ids.filter { !foundIDs.contains($0) }
            store.forget(missing)
        }
        estimateSize()
    }

    private func estimateSize() {
        sizeTask?.cancel()
        let assets = assets
        guard !assets.isEmpty else {
            estimatedBytes = 0
            return
        }
        estimatedBytes = nil
        sizeTask = Task { [weak self] in
            let bytes = await Task.detached(priority: .utility) {
                Self.totalFileSize(of: assets)
            }.value
            guard !Task.isCancelled, let self else { return }
            estimatedBytes = bytes
        }
    }

    /// Somma le dimensioni degli asset; `nil` se nessuna è disponibile, così
    /// si mostra solo il conteggio.
    nonisolated private static func totalFileSize(of assets: [PHAsset]) -> Int64? {
        var total: Int64 = 0
        var foundAny = false
        for asset in assets {
            if Task.isCancelled { return nil }
            if let bytes = AssetFileSize.bytes(of: asset) {
                total += bytes
                foundAny = true
            }
        }
        return foundAny ? total : nil
    }
}
