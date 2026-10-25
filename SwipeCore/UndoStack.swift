import Foundation

/// Pila a capacità limitata: oltre la capacità scarta le voci più vecchie.
public struct UndoStack<Element> {
    public let capacity: Int
    public private(set) var elements: [Element] = []

    public init(capacity: Int = 20) {
        precondition(capacity > 0, "La capacità deve essere positiva")
        self.capacity = capacity
    }

    public var isEmpty: Bool { elements.isEmpty }
    public var count: Int { elements.count }
    public var last: Element? { elements.last }

    public mutating func push(_ element: Element) {
        elements.append(element)
        if elements.count > capacity {
            elements.removeFirst(elements.count - capacity)
        }
    }

    @discardableResult
    public mutating func pop() -> Element? {
        elements.popLast()
    }

    public mutating func removeAll(where shouldRemove: (Element) -> Bool) {
        elements.removeAll(where: shouldRemove)
    }

    public mutating func removeAll() {
        elements.removeAll()
    }
}

extension UndoStack: Sendable where Element: Sendable {}
extension UndoStack: Equatable where Element: Equatable {}

/// Un'azione di swipe annullabile.
public struct SwipeAction: Sendable, Equatable {
    public let item: QueueItem
    public let decision: Decision
    /// Decisione presente prima dello swipe (in modalità manuale un elemento
    /// già tenuto può essere rivalutato). Annullare la ripristina.
    public let previousDecision: Decision?

    public init(item: QueueItem, decision: Decision, previousDecision: Decision?) {
        self.item = item
        self.decision = decision
        self.previousDecision = previousDecision
    }
}
