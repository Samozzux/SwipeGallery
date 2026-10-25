import Foundation
import SwiftData
import SwipeCore

/// Decisione salvata per un elemento della libreria, legata al suo
/// `localIdentifier`: vale ovunque l'elemento compaia (galleria o album).
@Model
final class AssetDecision {
    @Attribute(.unique) var localIdentifier: String
    /// Salvato come stringa: i predicati SwiftData sugli enum sono fragili.
    var decisionRawValue: String
    var decidedAt: Date

    var decision: Decision {
        get { Decision(rawValue: decisionRawValue) ?? .kept }
        set { decisionRawValue = newValue.rawValue }
    }

    init(localIdentifier: String, decision: Decision, decidedAt: Date = .now) {
        self.localIdentifier = localIdentifier
        self.decisionRawValue = decision.rawValue
        self.decidedAt = decidedAt
    }
}
