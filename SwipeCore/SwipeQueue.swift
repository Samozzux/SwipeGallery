import Foundation

/// Sorgente indicizzata di identificatori, ordinata dal più recente (indice 0)
/// al più vecchio. In app è un `PHFetchResult`, nei test un array.
public protocol IdentifierSource {
    var count: Int { get }
    func identifier(at index: Int) -> String
}

/// Direzione di scorrimento della coda.
public enum QueueDirection: Sendable, Equatable {
    /// Verso gli elementi più vecchi (indici crescenti).
    case towardOlder
    /// Verso gli elementi più recenti (indici decrescenti).
    case towardNewer

    public var step: Int {
        self == .towardOlder ? 1 : -1
    }

    public var reversed: QueueDirection {
        self == .towardOlder ? .towardNewer : .towardOlder
    }
}

/// Un elemento della coda: posizione nella sorgente e identificatore stabile.
public struct QueueItem: Hashable, Sendable {
    public let index: Int
    public let id: String

    public init(index: Int, id: String) {
        self.index = index
        self.id = id
    }
}

/// Coda di swipe che scorre la sorgente per indice, senza mai convertirla in
/// array: le librerie possono contenere decine di migliaia di elementi.
///
/// Gli elementi esclusi (per esempio già decisi) vengono saltati in modo pigro,
/// e il filtro viene riapplicato anche agli elementi già bufferizzati, perché
/// una decisione presa altrove può cambiare cosa va mostrato.
public struct SwipeQueue<Source: IdentifierSource> {
    public private(set) var source: Source
    public private(set) var direction: QueueDirection

    /// Prossimo indice della sorgente ancora da esaminare.
    private var cursor: Int
    /// Elementi già esaminati e accettati, in ordine di presentazione.
    /// Il primo è l'elemento corrente.
    private var buffer: [QueueItem] = []

    public init(source: Source, startIndex: Int = 0, direction: QueueDirection = .towardOlder) {
        self.source = source
        self.direction = direction
        self.cursor = Self.clampedCursor(startIndex, count: source.count, direction: direction)
    }

    /// I prossimi `limit` elementi da mostrare; il primo è quello corrente.
    public mutating func upcoming(_ limit: Int, isExcluded: (String) -> Bool) -> [QueueItem] {
        buffer.removeAll { isExcluded($0.id) }
        while buffer.count < limit, let next = nextFromSource(isExcluded: isExcluded) {
            buffer.append(next)
        }
        return Array(buffer.prefix(limit))
    }

    public mutating func current(isExcluded: (String) -> Bool) -> QueueItem? {
        upcoming(1, isExcluded: isExcluded).first
    }

    /// Toglie un elemento dalla coda (dopo una decisione, o se l'asset non
    /// esiste più).
    public mutating func remove(id: String) {
        buffer.removeAll { $0.id == id }
    }

    /// Rimette un elemento in cima alla coda (annulla).
    public mutating func pushFront(_ item: QueueItem) {
        buffer.removeAll { $0.id == item.id }
        buffer.insert(item, at: 0)
    }

    /// Inverte la direzione mantenendo l'elemento corrente in cima.
    public mutating func reverseDirection(isExcluded: (String) -> Bool) {
        let current = current(isExcluded: isExcluded)
        direction = direction.reversed
        buffer.removeAll()
        if let current {
            buffer = [current]
            cursor = current.index + direction.step
        } else {
            cursor += direction.step
        }
        cursor = Self.clampedCursor(cursor, count: source.count, direction: direction)
    }

    /// Sostituisce la sorgente (la libreria è cambiata). Gli elementi `pinned`
    /// restano in cima nell'ordine dato; la scansione riparte da `cursor`.
    public mutating func replaceSource(_ newSource: Source, cursor newCursor: Int, pinned: [QueueItem] = []) {
        source = newSource
        buffer = pinned
        cursor = Self.clampedCursor(newCursor, count: newSource.count, direction: direction)
    }

    /// Numero di elementi ancora da mostrare. Scorre tutta la parte non
    /// esaminata della sorgente: va chiamato fuori dal main thread su librerie
    /// grandi.
    public func remainingCount(isExcluded: (String) -> Bool) -> Int {
        let buffered = buffer.filter { !isExcluded($0.id) }
        let bufferedIDs = Set(buffered.map(\.id))
        var count = buffered.count
        var index = cursor
        while index >= 0, index < source.count {
            let id = source.identifier(at: index)
            if !isExcluded(id), !bufferedIDs.contains(id) {
                count += 1
            }
            index += direction.step
        }
        return count
    }

    private mutating func nextFromSource(isExcluded: (String) -> Bool) -> QueueItem? {
        while cursor >= 0, cursor < source.count {
            let index = cursor
            cursor += direction.step
            let id = source.identifier(at: index)
            if isExcluded(id) || buffer.contains(where: { $0.id == id }) {
                continue
            }
            return QueueItem(index: index, id: id)
        }
        return nil
    }

    /// Riporta il cursore nell'intervallo utile per la direzione. Il valore
    /// `count` (verso i più vecchi) o -1 (verso i più recenti) indica una coda
    /// esaurita.
    private static func clampedCursor(_ value: Int, count: Int, direction: QueueDirection) -> Int {
        switch direction {
        case .towardOlder: min(max(value, 0), count)
        case .towardNewer: min(max(value, -1), count - 1)
        }
    }
}

extension SwipeQueue: Sendable where Source: Sendable {}

/// Sorgente basata su array, utile per i test e le anteprime.
public struct ArraySource: IdentifierSource, Sendable {
    public var identifiers: [String]

    public init(_ identifiers: [String]) {
        self.identifiers = identifiers
    }

    public var count: Int { identifiers.count }

    public func identifier(at index: Int) -> String {
        identifiers[index]
    }
}
