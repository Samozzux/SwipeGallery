import Foundation
import Observation
import Photos
import SwipeCore

/// Un gruppo di foto doppie o simili.
struct SimilarGroup: Identifiable, Equatable {
    let assets: [PHAsset]
    /// Foto che conviene tenere secondo `BestShot`.
    let suggestedKeepID: String?

    var id: String { assets.first?.localIdentifier ?? "" }
}

/// Analisi delle foto simili: calcolo delle impronte (lento, con cache) e
/// raggruppamento (veloce, rifatto quando cambia la sensibilità).
@MainActor
@Observable
final class SimilarPhotosModel {
    enum Phase: Equatable {
        case idle
        case analyzing(done: Int, total: Int)
        case grouping
        case ready
    }

    private(set) var phase: Phase = .idle
    private(set) var groups: [SimilarGroup] = []
    private(set) var analyzedCount = 0

    @ObservationIgnored private var items: [SimilarityItem] = []
    @ObservationIgnored private var cancellation: ScanCancellation?
    @ObservationIgnored private var groupTask: Task<Void, Never>?
    @ObservationIgnored private var analyzedChangeCount: Int?

    var isAnalyzing: Bool {
        if case .analyzing = phase { return true }
        return false
    }

    /// Un'analisi è già stata fatta in passato: le prossime sono incrementali.
    var hasPreviousAnalysis: Bool {
        FeaturePrintCache.exists
    }

    /// La libreria è cambiata dall'ultima analisi.
    func isStale(for library: PhotoLibraryService) -> Bool {
        analyzedChangeCount != library.changeCount
    }

    func analyze(library: PhotoLibraryService, sensitivity: SimilaritySensitivity) {
        guard !isAnalyzing, library.hasAccess else { return }
        let cancellation = ScanCancellation()
        self.cancellation = cancellation
        let changeCount = library.changeCount
        let photos = Self.fetchPhotos()
        phase = .analyzing(done: 0, total: photos.count)
        SystemActions.setKeepScreenAwake(true)

        let report: @Sendable (SimilarityScanner.Progress) -> Void = { [weak self] progress in
            Task { @MainActor in
                self?.apply(progress)
            }
        }
        Task {
            let items = await SimilarityScanner.analyze(photos, cancellation: cancellation, progress: report)
            SystemActions.setKeepScreenAwake(false)
            self.cancellation = nil
            if cancellation.isCancelled {
                phase = groups.isEmpty && self.items.isEmpty ? .idle : .ready
                return
            }
            self.items = items
            analyzedCount = items.count
            analyzedChangeCount = changeCount
            startGrouping(library: library, sensitivity: sensitivity)
        }
    }

    func cancel() {
        cancellation?.cancel()
    }

    /// Rifà i gruppi dalle impronte già calcolate (cambio di sensibilità).
    func regroup(library: PhotoLibraryService, sensitivity: SimilaritySensitivity) {
        guard !isAnalyzing, !items.isEmpty else { return }
        startGrouping(library: library, sensitivity: sensitivity)
    }

    /// Raggruppa le impronte in memoria. Viene chiamata anche alla fine
    /// dell'analisi, quando lo stato è ancora `.analyzing`: per questo non
    /// controlla `isAnalyzing`.
    private func startGrouping(library: PhotoLibraryService, sensitivity: SimilaritySensitivity) {
        groupTask?.cancel()
        let items = items
        guard !items.isEmpty else {
            groups = []
            phase = .ready
            return
        }
        phase = .grouping
        let options = SimilarityOptions.preset(sensitivity)
        groupTask = Task {
            let indexGroups = await Task.detached(priority: .userInitiated) {
                SimilarityGrouper.groups(items, options: options)
            }.value
            guard !Task.isCancelled else { return }
            groups = Self.resolve(indexGroups.map { $0.map { items[$0].id } }, library: library)
            phase = .ready
        }
    }

    private func apply(_ progress: SimilarityScanner.Progress) {
        guard isAnalyzing else { return }
        phase = .analyzing(done: progress.done, total: progress.total)
    }

    /// Solo foto, dalla più vecchia: l'analisi confronta scatti consecutivi.
    private static func fetchPhotos() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    private static func resolve(_ idGroups: [[String]], library: PhotoLibraryService) -> [SimilarGroup] {
        let assets = library.assets(withIDs: idGroups.flatMap { $0 })
        let byID = Dictionary(assets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        return idGroups.compactMap { ids in
            let members = ids.compactMap { byID[$0] }
            guard members.count > 1 else { return nil }
            let candidates = members.map {
                ShotCandidate(
                    id: $0.localIdentifier,
                    pixelCount: $0.pixelWidth * $0.pixelHeight,
                    isFavorite: $0.isFavorite,
                    isEdited: $0.hasAdjustments,
                    date: $0.creationDate
                )
            }
            let best = BestShot.bestIndex(candidates).map { members[$0].localIdentifier }
            return SimilarGroup(assets: members, suggestedKeepID: best)
        }
    }
}

extension SimilarGroup {
    /// Membri non ancora nel cestino.
    func activeAssets(_ decisions: DecisionIndex) -> [PHAsset] {
        assets.filter { !decisions.isTrashed($0.localIdentifier) }
    }

    /// Un gruppo va mostrato se ha ancora almeno due foto fuori dal cestino e,
    /// salvo `includeReviewed`, almeno una ancora da valutare.
    func isVisible(_ decisions: DecisionIndex, includeReviewed: Bool) -> Bool {
        let active = activeAssets(decisions)
        guard active.count > 1 else { return false }
        return includeReviewed || active.contains { decisions.decision(for: $0.localIdentifier) == nil }
    }
}

extension SimilaritySensitivity {
    var title: String {
        switch self {
        case .strict: "Solo quasi identiche"
        case .balanced: "Bilanciata"
        case .loose: "Anche solo simili"
        }
    }
}
