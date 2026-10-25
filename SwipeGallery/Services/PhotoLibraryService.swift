import Foundation
import Observation
import Photos

/// Accesso alla Libreria Foto: permessi, fetch, eliminazione e osservazione
/// dei cambiamenti.
@MainActor
@Observable
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var authorization: PHAuthorizationStatus
    /// Tutte le foto (e i video, se inclusi) dal più recente.
    private(set) var allAssets: PHFetchResult<PHAsset>
    /// Aumenta a ogni cambiamento della libreria: chi tiene dei fetch result
    /// li rigenera.
    private(set) var changeCount = 0

    var includeVideos: Bool {
        didSet {
            guard includeVideos != oldValue else { return }
            refetch()
        }
    }

    /// Chiamato con gli identificatori di elementi che non esistono più.
    @ObservationIgnored var onAssetsRemoved: (@MainActor ([String]) -> Void)?

    /// Fetch di tutti gli elementi, nascosti inclusi, usato solo per sapere
    /// quali elementi vengono eliminati dalla libreria.
    @ObservationIgnored private var trackingFetch: PHFetchResult<PHAsset>?
    @ObservationIgnored private var isObserving = false

    var hasAccess: Bool {
        authorization == .authorized || authorization == .limited
    }

    var isLimited: Bool {
        authorization == .limited
    }

    init(includeVideos: Bool) {
        self.includeVideos = includeVideos
        self.authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.allAssets = PHFetchResult<PHAsset>()
        super.init()
        if hasAccess {
            startObserving()
        }
    }

    // MARK: - Permessi

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        updateAuthorization(status)
    }

    /// Da chiamare quando l'app torna in primo piano: l'utente può aver
    /// cambiato il permesso nelle Impostazioni.
    func refreshAuthorization() {
        updateAuthorization(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func updateAuthorization(_ status: PHAuthorizationStatus) {
        let changed = status != authorization
        if changed {
            authorization = status
        }
        guard hasAccess else { return }
        if !isObserving {
            startObserving()
        } else if changed {
            refetch()
        }
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        PHPhotoLibrary.shared().register(self)
        trackingFetch = PHAsset.fetchAssets(with: Self.trackingOptions())
        refetch()
    }

    // MARK: - Fetch

    /// Opzioni comuni: ordinamento dal più recente e filtro sul tipo.
    nonisolated static func assetOptions(includeVideos: Bool) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if includeVideos {
            options.predicate = NSPredicate(
                format: "mediaType == %d OR mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )
        } else {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        return options
    }

    func fetchAssets(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        PHAsset.fetchAssets(in: collection, options: Self.assetOptions(includeVideos: includeVideos))
    }

    /// Asset per identificatore, nell'ordine dato; quelli che non esistono più
    /// vengono omessi.
    func assets(withIDs ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: Self.trackingOptions())
        var byID: [String: PHAsset] = [:]
        byID.reserveCapacity(result.count)
        for index in 0 ..< result.count {
            let asset = result.object(at: index)
            byID[asset.localIdentifier] = asset
        }
        return ids.compactMap { byID[$0] }
    }

    private func refetch() {
        guard hasAccess else { return }
        allAssets = PHAsset.fetchAssets(with: Self.assetOptions(includeVideos: includeVideos))
        changeCount += 1
    }

    nonisolated private static func trackingOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = true
        return options
    }

    // MARK: - Pulizia dei record orfani

    /// Rimuove i record di elementi che non esistono più. Con accesso limitato
    /// non si può distinguere un elemento eliminato da uno non selezionato,
    /// quindi non si fa nulla.
    func pruneMissingAssets(knownIDs: Set<String>) {
        guard authorization == .authorized, !knownIDs.isEmpty else { return }
        let ids = Array(knownIDs)
        Task {
            let missing = await Task.detached(priority: .utility) {
                Self.missingIdentifiers(among: ids)
            }.value
            if !missing.isEmpty {
                onAssetsRemoved?(missing)
            }
        }
    }

    nonisolated private static func missingIdentifiers(among ids: [String]) -> [String] {
        var existing = Set<String>()
        let chunkSize = 1_000
        var start = 0
        while start < ids.count {
            let chunk = Array(ids[start ..< min(start + chunkSize, ids.count)])
            let result = PHAsset.fetchAssets(withLocalIdentifiers: chunk, options: trackingOptions())
            for index in 0 ..< result.count {
                existing.insert(result.object(at: index).localIdentifier)
            }
            start += chunkSize
        }
        return ids.filter { !existing.contains($0) }
    }

    // MARK: - Eliminazione

    /// Elimina gli elementi dalla libreria con un'unica richiesta: iOS mostra
    /// la propria conferma di sistema.
    func deleteAssets(withIDs ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    // MARK: - PHPhotoLibraryChangeObserver

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.handle(changeInstance)
        }
    }

    private func handle(_ change: PHChange) {
        if let trackingFetch, let details = change.changeDetails(for: trackingFetch) {
            self.trackingFetch = details.fetchResultAfterChanges
            let removed = details.removedObjects.map(\.localIdentifier)
            if !removed.isEmpty, authorization == .authorized {
                onAssetsRemoved?(removed)
            }
        }
        // Con accesso limitato la selezione può cambiare: si rilegge lo stato.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != authorization {
            authorization = status
        }
        refetch()
    }
}
