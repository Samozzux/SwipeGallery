import Testing
@testable import SwipeCore

@Suite("UndoStack")
struct UndoStackTests {
    @Test("Annulla in ordine inverso (LIFO)")
    func lifo() {
        var stack = UndoStack<Int>(capacity: 20)
        stack.push(1)
        stack.push(2)
        stack.push(3)
        #expect(stack.pop() == 3)
        #expect(stack.pop() == 2)
        #expect(stack.pop() == 1)
        #expect(stack.pop() == nil)
        #expect(stack.isEmpty)
    }

    @Test("Tiene al massimo le ultime 20 azioni")
    func capacity() {
        var stack = UndoStack<Int>(capacity: 20)
        for value in 1...25 {
            stack.push(value)
        }
        #expect(stack.count == 20)
        #expect(stack.elements.first == 6)
        #expect(stack.last == 25)
    }

    @Test("removeAll(where:) toglie le voci indicate")
    func removeWhere() {
        var stack = UndoStack<Int>()
        for value in 1...5 {
            stack.push(value)
        }
        stack.removeAll { $0.isMultiple(of: 2) }
        #expect(stack.elements == [1, 3, 5])
    }
}
