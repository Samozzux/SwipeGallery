import Foundation

/// Esito della valutazione di un elemento della libreria.
public enum Decision: String, Codable, Sendable, CaseIterable {
    case kept
    case trashed
}
