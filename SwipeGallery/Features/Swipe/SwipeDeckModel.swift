import Foundation
import Observation
import Photos
import SwipeCore

/// Una card della pila: posizione nella coda e asset PhotoKit risolto.
struct DeckCard: Identifiable, Equatable {
    let item: QueueItem
    let asset: PHAsset

    var id: String { item.id }
}

/// Stato di una pila di swipe: coda, annulla, conteggio e precaricamento.
/// Tutta la logica di ordinamento e filtro sta in `SwipeQueue` e `QueueFilter`.
@MainActor
@Observable
final class SwipeDeckModel {
    let mode: QueueMode
    /// Elemento corrente e successivo (visibile in trasparenza dietro).
    private(set) var cards: [DeckCard] = []
    /// Elementi ancora da valutare in questa coda; `nil` finché il conteggio
    /// iniziale non è pronto.
    private(set) var remainingCount: Int?
    private(set) var direction: QueueDirection
    private(set) var canUndo = false
    /// Numero totale di elementi della sorgente, per "n / totale".
    private(set) var totalCount: Int

    var current: DeckCard? { cards.first }

    /// L'azione che verrebbe annullata, per far rientrare la card dal lato giusto.
    var lastAction: SwipeAction? { undoStack.last }

    @ObservationIgnored private var queue: SwipeQueue<FetchResultSource>
    @ObservationIgnored private var filter: QueueFilter
    @ObservationIgnored private var undoStack = UndoStack<SwipeAction>(capacity: 20)
    @ObservationIgnored private let store: DecisionStore
    @ObservationIgnored private var knownRevision: Int
    @ObservationIgnored private var knownResetGeneration: Int
    @ObservationIgnored private var countTask: Task<Void, Never>?
    /// Variazioni locali del conteggio avvenute mentre il conteggio in
    /// background era in corso.
    @ObservationIgnored private var pendingCountDelta = 0
    @ObservationIgnored private var lastIndex: Int?
    @ObservationIgnored var imageTargetSize: CGSize = .zero {
        didSet {
            if imageTargetSize != oldValue {
                updatePreloading()
            }
        }
    }
    /// Solo la pila visibile precarica: la cache di PhotoKit è condivisa.
    @ObservationIgnored var isVisible = false {
        didSet {
            if isVisible, !oldValue {
                updatePreloading()
            }
        }
    }

    /// Quanti elementi successivi precaricare alla risoluzione dello schermo.
    private static let preloadCount = 3

    init(
        fetchResult: PHFetchResult<PHAsset>,
        mode: QueueMode,
        startIndex: Int = 0,
        direction: QueueDirection = .towardOlder,
        store: DecisionStore
    ) {
        self.mode = mode
        self.direction = direction
        self.store = store
        self.filter = QueueFilter(mode: mode)
        self.queue = SwipeQueue(source: FetchResultSource(fetchResult: fetchResult), startIndex: startIndex, direction: direction)
        self.totalCount = fetchResult.count
        self.knownRevision = store.revision
        self.knownResetGeneration = store.resetGeneration
        refreshCards()
        scheduleRecount()
    }

    // MARK: - Azioni

    func decide(_ decision: Decision) {
        guard let card = current else { return }
        let previous = store.decision(for: card.id)
        queue.remove(id: card.id)
        store.setDecision(decision, for: card.id)
        knownRevision = store.revision
        filter.recordDecision(for: card.id)
        undoStack.push(SwipeAction(item: card.item, decision: decision, previousDecision: previous))
        canUndo = true
        adjustRemaining(by: -1)
        refreshCards()
    }

    /// Annulla l'ultima azione e restituisce la decisione annullata.
    @discardableResult
    func undo() -> SwipeAction? {
        guard let action = undoStack.pop() else { return nil }
        store.setDecision(action.previousDecision, for: action.item.id)
        knownRevision = store.revision
        filter.forgetDecision(for: action.item.id)
        queue.pushFront(action.item)
        canUndo = !undoStack.isEmpty
        adjustRemaining(by: 1)
        refreshCards()
        return action
    }

    func reverseDirection() {
        queue.reverseDirection(isExcluded: isExcluded)
        direction = queue.direction
        refreshCards()
        scheduleRecount()
    }

    // MARK: - Cambiamenti esterni

    /// La libreria è cambiata: si rigenera la coda mantenendo in cima
    /// l'elemento corrente, se esiste ancora.
    func updateSource(_ fetchResult: PHFetchResult<PHAsset>) {
        let source = FetchResultSource(fetchResult: fetchResult)
        var pinned: [QueueItem] = []
        if let card = current {
            let newIndex = fetchResult.index(of: card.asset)
            if newIndex != NSNotFound {
                pinned = [QueueItem(index: newIndex, id: card.id)]
            }
        }
        var cursor = restartCursor(pinned: pinned.first, count: fetchResult.count, fromStart: false)
        // Coda già esaurita e nessun elemento nuovo: resta esaurita senza
        // riscorrere tutta la libreria.
        if mode == .unrated, cards.isEmpty, fetchResult.count <= totalCount {
            cursor = fetchResult.count
        }
        queue.replaceSource(source, cursor: cursor, pinned: pinned)
        totalCount = fetchResult.count
        refreshCards()
        scheduleRecount()
    }

    /// Da chiamare quando cambiano le decisioni: se la modifica viene da
    /// un'altra parte dell'app (un album, il cestino, le impostazioni) la coda
    /// si riallinea.
    func decisionsDidChange() {
        if store.resetGeneration != knownResetGeneration {
            knownResetGeneration = store.resetGeneration
            knownRevision = store.revision
            restart()
        } else if store.revision != knownRevision {
            knownRevision = store.revision
            refreshCards()
            scheduleRecount()
        }
    }

    /// Riparte dall'inizio (coda predefinita) o dall'elemento corrente
    /// (coda manuale), così gli elementi tornati "da valutare" ricompaiono.
    private func restart() {
        let pinned = current.map { [$0.item] } ?? []
        let cursor = restartCursor(pinned: pinned.first, count: queue.source.count, fromStart: true)
        queue.replaceSource(queue.source, cursor: cursor, pinned: pinned)
        refreshCards()
        scheduleRecount()
    }

    /// Da dove riprendere la scansione. La coda predefinita riparte da zero
    /// solo quando degli elementi sono tornati "da valutare"; negli altri casi
    /// prosegue dall'elemento corrente, per non riscorrere sul main thread
    /// migliaia di elementi già decisi a ogni cambiamento della libreria.
    private func restartCursor(pinned: QueueItem?, count: Int, fromStart: Bool) -> Int {
        switch mode {
        case .unrated:
            if fromStart {
                return 0
            }
            return pinned.map { $0.index + 1 } ?? 0
        case .manual:
            if let pinned {
                return pinned.index + direction.step
            }
            return min(lastIndex ?? 0, max(count - 1, 0))
        }
    }

    // MARK: - Coda

    private func isExcluded(_ id: String) -> Bool {
        filter.excludes(id, decisions: store.index)
    }

    /// Risolve le prime due card; gli elementi il cui asset non esiste più
    /// vengono tolti dalla coda.
    private func refreshCards() {
        var resolved: [DeckCard] = []
        var attempts = 0
        while attempts < 50 {
            attempts += 1
            resolved = []
            var missing: String?
            for item in queue.upcoming(2, isExcluded: isExcluded) {
                guard let asset = resolveAsset(item) else {
                    missing = item.id
                    break
                }
                resolved.append(DeckCard(item: item, asset: asset))
            }
            guard let missing else { break }
            queue.remove(id: missing)
        }
        if resolved != cards {
            cards = resolved
        }
        if let index = resolved.first?.item.index {
            lastIndex = index
        }
        updatePreloading()
    }

    private func resolveAsset(_ item: QueueItem) -> PHAsset? {
        if let asset = queue.source.asset(at: item.index), asset.localIdentifier == item.id {
            return asset
        }
        return PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject
    }

    /// Precarica i 3 elementi successivi a quello corrente.
    private func updatePreloading() {
        guard isVisible, imageTargetSize.width > 0 else { return }
        let upcoming = queue.upcoming(Self.preloadCount + 1, isExcluded: isExcluded).dropFirst()
        let assets = upcoming.compactMap { resolveAsset($0) }
        ImageLoader.shared.updateDeckCache(Array(assets), targetSize: imageTargetSize)
        // Se la prossima card è un video, lo si prepara mentre si guarda questa.
        if let next = assets.first, next.mediaType == .video {
            ImageLoader.shared.prefetchVideo(next)
        }
    }

    // MARK: - Conteggio

    private func adjustRemaining(by delta: Int) {
        if let remainingCount {
            self.remainingCount = max(remainingCount + delta, 0)
        }
        if countTask != nil {
            pendingCountDelta += delta
        }
    }

    /// Conta gli elementi rimanenti in background: su librerie grandi la
    /// scansione completa non deve bloccare l'interfaccia.
    private func scheduleRecount() {
        countTask?.cancel()
        pendingCountDelta = 0
        let snapshot = queue
        let filter = filter
        let decisions = store.index
        countTask = Task { [weak self] in
            let count = await Task.detached(priority: .userInitiated) {
                snapshot.remainingCount { filter.excludes($0, decisions: decisions) }
            }.value
            guard !Task.isCancelled, let self else { return }
            self.remainingCount = max(count + self.pendingCountDelta, 0)
            self.pendingCountDelta = 0
            self.countTask = nil
        }
    }
}
