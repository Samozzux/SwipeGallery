import Foundation
import Observation
import Photos
import SwipeCore

/// Modalità di visualizzazione di Galleria e Album.
enum BrowserMode: String, CaseIterable, Identifiable {
    case swipe
    case grid

    var id: Self { self }

    var title: String {
        switch self {
        case .swipe: "Swipe"
        case .grid: "Griglia"
        }
    }

    var systemImage: String {
        switch self {
        case .swipe: "rectangle.portrait.on.rectangle.portrait"
        case .grid: "square.grid.3x3"
        }
    }
}

/// Stato condiviso da Galleria e Album: fetch result, coda predefinita e
/// coda manuale avviata dalla griglia.
@MainActor
@Observable
final class AssetBrowserModel {
    enum Scope {
        case library
        case album(PHAssetCollection)
    }

    let scope: Scope
    var mode: BrowserMode = .swipe
    private(set) var fetchResult: PHFetchResult<PHAsset>
    private(set) var defaultDeck: SwipeDeckModel
    /// Coda avviata toccando una miniatura: include anche gli elementi tenuti.
    private(set) var manualDeck: SwipeDeckModel?

    var activeDeck: SwipeDeckModel { manualDeck ?? defaultDeck }

    @ObservationIgnored private let library: PhotoLibraryService
    @ObservationIgnored private let store: DecisionStore
    @ObservationIgnored private var knownChangeCount: Int

    init(scope: Scope, library: PhotoLibraryService, store: DecisionStore) {
        self.scope = scope
        self.library = library
        self.store = store
        let fetchResult = Self.fetch(scope, library: library)
        self.fetchResult = fetchResult
        self.defaultDeck = SwipeDeckModel(fetchResult: fetchResult, mode: .unrated, store: store)
        self.knownChangeCount = library.changeCount
    }

    func startManual(at index: Int, direction: QueueDirection) {
        let deck = SwipeDeckModel(
            fetchResult: fetchResult,
            mode: .manual,
            startIndex: index,
            direction: direction,
            store: store
        )
        deck.imageTargetSize = defaultDeck.imageTargetSize
        manualDeck = deck
        mode = .swipe
    }

    func exitManual() {
        manualDeck = nil
    }

    func libraryDidChange() {
        guard library.changeCount != knownChangeCount else { return }
        knownChangeCount = library.changeCount
        fetchResult = Self.fetch(scope, library: library)
        defaultDeck.updateSource(fetchResult)
        manualDeck?.updateSource(fetchResult)
    }

    func decisionsDidChange() {
        defaultDeck.decisionsDidChange()
        manualDeck?.decisionsDidChange()
    }

    private static func fetch(_ scope: Scope, library: PhotoLibraryService) -> PHFetchResult<PHAsset> {
        switch scope {
        case .library:
            library.allAssets
        case let .album(collection):
            library.fetchAssets(in: collection)
        }
    }
}
