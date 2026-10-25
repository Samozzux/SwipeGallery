import Foundation

/// Come una coda di swipe sceglie quali elementi mostrare.
public enum QueueMode: Sendable, Equatable {
    /// Coda predefinita: solo gli elementi non ancora valutati.
    case unrated
    /// Avvio manuale dalla griglia: anche gli elementi già tenuti, che si
    /// possono rivalutare. Restano esclusi quelli nel cestino.
    case manual
}

/// Regola di esclusione di una coda, separata da PhotoKit per poterla testare.
public struct QueueFilter: Sendable, Equatable {
    public let mode: QueueMode
    /// Elementi decisi in questa sessione della coda. In modalità manuale non
    /// vanno riproposti se si inverte la direzione.
    public private(set) var sessionDecided: Set<String> = []

    public init(mode: QueueMode) {
        self.mode = mode
    }

    public func excludes(_ id: String, decisions: DecisionIndex) -> Bool {
        switch mode {
        case .unrated:
            decisions.isDecided(id)
        case .manual:
            decisions.isTrashed(id) || sessionDecided.contains(id)
        }
    }

    public mutating func recordDecision(for id: String) {
        sessionDecided.insert(id)
    }

    public mutating func forgetDecision(for id: String) {
        sessionDecided.remove(id)
    }
}
