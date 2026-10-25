import Foundation

/// Lato dello schermo verso cui si trascina una card.
public enum SwipeEdge: String, Sendable, CaseIterable {
    case left
    case right

    public var opposite: SwipeEdge {
        self == .left ? .right : .left
    }
}

/// Pulsanti della barra di supporto allo swipe.
public enum SwipeButton: Sendable, Equatable {
    case trash
    case undo
    case keep
}

/// Associazione fra lati e decisioni, configurabile nelle Impostazioni.
public struct SwipeLayout: Sendable, Equatable {
    public var trashEdge: SwipeEdge

    public init(trashEdge: SwipeEdge = .left) {
        self.trashEdge = trashEdge
    }

    public func decision(for edge: SwipeEdge) -> Decision {
        edge == trashEdge ? .trashed : .kept
    }

    public func edge(for decision: Decision) -> SwipeEdge {
        decision == .trashed ? trashEdge : trashEdge.opposite
    }

    /// Ordine dei pulsanti da sinistra a destra, coerente con i lati dello swipe.
    public var buttonOrder: [SwipeButton] {
        trashEdge == .left ? [.trash, .undo, .keep] : [.keep, .undo, .trash]
    }
}

/// Regole numeriche del gesto di swipe.
public struct SwipeThreshold: Sendable, Equatable {
    /// Frazione della larghezza oltre cui l'azione scatta.
    public var distanceFraction: Double
    /// Velocità finale (punti/s) che fa scattare l'azione anche sotto soglia.
    public var flickVelocity: Double
    /// Spostamento minimo perché un colpo veloce conti.
    public var flickMinimumDistance: Double
    /// Rotazione massima della card, in gradi.
    public var maxRotationDegrees: Double

    public init(
        distanceFraction: Double = 0.3,
        flickVelocity: Double = 800,
        flickMinimumDistance: Double = 24,
        maxRotationDegrees: Double = 12
    ) {
        self.distanceFraction = distanceFraction
        self.flickVelocity = flickVelocity
        self.flickMinimumDistance = flickMinimumDistance
        self.maxRotationDegrees = maxRotationDegrees
    }

    /// Lato verso cui scatta l'azione al rilascio, oppure `nil` se la card
    /// deve tornare al centro.
    public func committedEdge(translation: Double, velocity: Double, width: Double) -> SwipeEdge? {
        guard width > 0 else { return nil }
        let edge: SwipeEdge = translation < 0 ? .left : .right
        if abs(translation) >= width * distanceFraction {
            return edge
        }
        let isFlick = abs(velocity) >= flickVelocity
            && abs(translation) >= flickMinimumDistance
            && (velocity < 0) == (translation < 0)
        return isFlick ? edge : nil
    }

    /// Avanzamento verso la soglia, da 0 a 1: guida l'opacità delle etichette.
    public func progress(translation: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(abs(translation) / (width * distanceFraction), 1)
    }

    /// Rotazione proporzionale allo spostamento, limitata a `maxRotationDegrees`.
    public func rotationDegrees(translation: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        let ratio = max(min(translation / width, 1), -1)
        return ratio * maxRotationDegrees
    }
}
