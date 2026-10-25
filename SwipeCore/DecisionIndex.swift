import Foundation

/// Vista in memoria di tutte le decisioni salvate, pensata per filtrare le code
/// in O(1) per elemento senza interrogare il database.
public struct DecisionIndex: Sendable, Equatable {
    public private(set) var keptIDs: Set<String> = []
    public private(set) var trashedDates: [String: Date] = [:]

    public init() {}

    public init(entries: some Sequence<(id: String, decision: Decision, date: Date)>) {
        for entry in entries {
            set(entry.decision, for: entry.id, at: entry.date)
        }
    }

    public var keptCount: Int { keptIDs.count }
    public var trashedCount: Int { trashedDates.count }
    public var isEmpty: Bool { keptIDs.isEmpty && trashedDates.isEmpty }

    /// Tutti gli identificatori che hanno una decisione.
    public var allIDs: Set<String> { keptIDs.union(trashedDates.keys) }

    public func decision(for id: String) -> Decision? {
        if trashedDates[id] != nil { return .trashed }
        if keptIDs.contains(id) { return .kept }
        return nil
    }

    public func isDecided(_ id: String) -> Bool {
        trashedDates[id] != nil || keptIDs.contains(id)
    }

    public func isTrashed(_ id: String) -> Bool {
        trashedDates[id] != nil
    }

    public func isKept(_ id: String) -> Bool {
        keptIDs.contains(id)
    }

    /// Elementi nel cestino, dal più recentemente scartato.
    public var trashedIDsByRecency: [String] {
        trashedDates
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .map(\.key)
    }

    /// Imposta (o rimuove, con `nil`) la decisione per un elemento.
    public mutating func set(_ decision: Decision?, for id: String, at date: Date = .now) {
        switch decision {
        case .kept:
            trashedDates[id] = nil
            keptIDs.insert(id)
        case .trashed:
            keptIDs.remove(id)
            trashedDates[id] = date
        case nil:
            keptIDs.remove(id)
            trashedDates[id] = nil
        }
    }

    public mutating func remove(_ ids: some Sequence<String>) {
        for id in ids {
            set(nil, for: id)
        }
    }

    /// Rimuove tutte le decisioni "tenuto", lasciando invariato il cestino.
    /// Restituisce gli identificatori rimossi.
    @discardableResult
    public mutating func removeAllKept() -> Set<String> {
        let removed = keptIDs
        keptIDs.removeAll()
        return removed
    }
}
