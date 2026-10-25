import Foundation
import Testing
@testable import SwipeCore

@Suite("Decisioni e filtri")
struct DecisionFilteringTests {
    @Test("Una decisione sostituisce la precedente")
    func setReplaces() {
        var index = DecisionIndex()
        index.set(.kept, for: "x")
        #expect(index.decision(for: "x") == .kept)
        index.set(.trashed, for: "x")
        #expect(index.decision(for: "x") == .trashed)
        #expect(index.keptCount == 0)
        #expect(index.trashedCount == 1)
        index.set(nil, for: "x")
        #expect(index.decision(for: "x") == nil)
        #expect(index.isEmpty)
    }

    @Test("Il cestino è ordinato dal più recentemente scartato")
    func trashOrder() {
        let base = Date(timeIntervalSince1970: 1_000)
        var index = DecisionIndex()
        index.set(.trashed, for: "old", at: base)
        index.set(.trashed, for: "new", at: base.addingTimeInterval(60))
        index.set(.trashed, for: "mid", at: base.addingTimeInterval(30))
        #expect(index.trashedIDsByRecency == ["new", "mid", "old"])
    }

    @Test("Azzera progresso rimuove solo i tenuti")
    func resetKept() {
        var index = DecisionIndex()
        index.set(.kept, for: "k1")
        index.set(.kept, for: "k2")
        index.set(.trashed, for: "t1")
        let removed = index.removeAllKept()
        #expect(removed == ["k1", "k2"])
        #expect(index.keptCount == 0)
        #expect(index.isTrashed("t1"))
    }

    @Test("Inizializzazione dai record salvati")
    func initFromEntries() {
        let date = Date(timeIntervalSince1970: 0)
        let index = DecisionIndex(entries: [
            (id: "a", decision: .kept, date: date),
            (id: "b", decision: .trashed, date: date),
        ])
        #expect(index.allIDs == ["a", "b"])
        #expect(index.isKept("a"))
        #expect(index.isTrashed("b"))
    }

    @Test("La coda predefinita esclude tenuti e cestinati")
    func unratedFilter() {
        var index = DecisionIndex()
        index.set(.kept, for: "k")
        index.set(.trashed, for: "t")
        let filter = QueueFilter(mode: .unrated)
        #expect(filter.excludes("k", decisions: index))
        #expect(filter.excludes("t", decisions: index))
        #expect(!filter.excludes("n", decisions: index))
    }

    @Test("La coda manuale ripropone i tenuti ma non i cestinati")
    func manualFilter() {
        var index = DecisionIndex()
        index.set(.kept, for: "k")
        index.set(.trashed, for: "t")
        var filter = QueueFilter(mode: .manual)
        #expect(!filter.excludes("k", decisions: index))
        #expect(filter.excludes("t", decisions: index))
        filter.recordDecision(for: "k")
        #expect(filter.excludes("k", decisions: index))
        filter.forgetDecision(for: "k")
        #expect(!filter.excludes("k", decisions: index))
    }

    @Test("Flusso completo: swipe, annulla e azzera progresso")
    func fullFlow() {
        let source = ArraySource(["a", "b", "c", "d"])
        var index = DecisionIndex()
        let filter = QueueFilter(mode: .unrated)
        var queue = SwipeQueue(source: source)
        var undo = UndoStack<SwipeAction>()

        func swipe(_ decision: Decision) {
            let item = queue.current { filter.excludes($0, decisions: index) }!
            let previous = index.decision(for: item.id)
            queue.remove(id: item.id)
            index.set(decision, for: item.id)
            undo.push(SwipeAction(item: item, decision: decision, previousDecision: previous))
        }

        swipe(.kept)
        swipe(.trashed)
        #expect(queue.current { filter.excludes($0, decisions: index) }?.id == "c")
        #expect(queue.remainingCount { filter.excludes($0, decisions: index) } == 2)

        let action = undo.pop()!
        index.set(action.previousDecision, for: action.item.id)
        queue.pushFront(action.item)
        #expect(action.item.id == "b")
        #expect(queue.current { filter.excludes($0, decisions: index) }?.id == "b")
        #expect(index.decision(for: "b") == nil)

        // Dopo un riavvio la coda riparte da zero e salta i tenuti.
        var restarted = SwipeQueue(source: source)
        #expect(restarted.current { filter.excludes($0, decisions: index) }?.id == "b")

        // Azzera progresso: "a" torna da valutare.
        index.removeAllKept()
        var afterReset = SwipeQueue(source: source)
        #expect(afterReset.current { filter.excludes($0, decisions: index) }?.id == "a")
    }
}
