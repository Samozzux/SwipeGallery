import Testing
@testable import SwipeCore

@Suite("SwipeQueue")
struct SwipeQueueTests {
    /// "a0" è il più recente, "a9" il più vecchio.
    let source = ArraySource((0..<10).map { "a\($0)" })

    @Test("La coda predefinita parte dal più recente e va verso i più vecchi")
    func defaultOrder() {
        var queue = SwipeQueue(source: source)
        let ids = queue.upcoming(3) { _ in false }.map(\.id)
        #expect(ids == ["a0", "a1", "a2"])
    }

    @Test("Gli elementi esclusi vengono saltati")
    func skipsExcluded() {
        var queue = SwipeQueue(source: source)
        let excluded: Set = ["a0", "a2", "a3"]
        let ids = queue.upcoming(3) { excluded.contains($0) }.map(\.id)
        #expect(ids == ["a1", "a4", "a5"])
    }

    @Test("Il filtro si riapplica agli elementi già bufferizzati")
    func refiltersBuffer() {
        var queue = SwipeQueue(source: source)
        _ = queue.upcoming(3) { _ in false }
        var excluded: Set<String> = ["a1"]
        let ids = queue.upcoming(3) { excluded.contains($0) }.map(\.id)
        #expect(ids == ["a0", "a2", "a3"])
        excluded.insert("a0")
        #expect(queue.current { excluded.contains($0) }?.id == "a2")
    }

    @Test("Rimuovere l'elemento corrente fa avanzare la coda")
    func removeAdvances() {
        var queue = SwipeQueue(source: source)
        let first = queue.current { _ in false }
        #expect(first?.id == "a0")
        queue.remove(id: "a0")
        #expect(queue.current { _ in false }?.id == "a1")
    }

    @Test("Avvio manuale verso le più recenti a partire da un indice")
    func manualTowardNewer() {
        var queue = SwipeQueue(source: source, startIndex: 4, direction: .towardNewer)
        let ids = queue.upcoming(10) { _ in false }.map(\.id)
        #expect(ids == ["a4", "a3", "a2", "a1", "a0"])
    }

    @Test("Avvio manuale verso le più vecchie a partire da un indice")
    func manualTowardOlder() {
        var queue = SwipeQueue(source: source, startIndex: 7, direction: .towardOlder)
        let ids = queue.upcoming(10) { _ in false }.map(\.id)
        #expect(ids == ["a7", "a8", "a9"])
    }

    @Test("pushFront rimette l'elemento in cima senza duplicarlo")
    func pushFront() {
        var queue = SwipeQueue(source: source)
        let first = queue.current { _ in false }!
        queue.remove(id: first.id)
        queue.pushFront(first)
        queue.pushFront(first)
        let ids = queue.upcoming(3) { _ in false }.map(\.id)
        #expect(ids == ["a0", "a1", "a2"])
    }

    @Test("Un elemento rimesso in cima e ancora da esaminare non viene riproposto due volte")
    func pushFrontOfUnscannedItem() {
        var queue = SwipeQueue(source: source)
        queue.pushFront(QueueItem(index: 5, id: "a5"))
        let ids = queue.upcoming(10) { _ in false }.map(\.id)
        #expect(ids == ["a5", "a0", "a1", "a2", "a3", "a4", "a6", "a7", "a8", "a9"])
        #expect(queue.remainingCount { _ in false } == 10)
    }

    @Test("Invertire la direzione mantiene l'elemento corrente in cima")
    func reverseKeepsCurrent() {
        var queue = SwipeQueue(source: source, startIndex: 5, direction: .towardOlder)
        _ = queue.upcoming(3) { _ in false }
        queue.reverseDirection { _ in false }
        #expect(queue.direction == .towardNewer)
        let ids = queue.upcoming(10) { _ in false }.map(\.id)
        #expect(ids == ["a5", "a4", "a3", "a2", "a1", "a0"])
    }

    @Test("Invertire una coda esaurita riparte dall'estremo raggiunto")
    func reverseExhaustedQueue() {
        var queue = SwipeQueue(source: source, startIndex: 8, direction: .towardOlder)
        for item in queue.upcoming(10, isExcluded: { _ in false }) {
            queue.remove(id: item.id)
        }
        #expect(queue.current { _ in false } == nil)
        let decided: Set = ["a8", "a9"]
        queue.reverseDirection { decided.contains($0) }
        #expect(queue.current { decided.contains($0) }?.id == "a7")
    }

    @Test("Il conteggio rimanente rispetta esclusioni e buffer")
    func remainingCount() {
        var queue = SwipeQueue(source: source)
        let excluded: Set = ["a3", "a7"]
        #expect(queue.remainingCount { excluded.contains($0) } == 8)
        _ = queue.upcoming(4) { excluded.contains($0) }
        #expect(queue.remainingCount { excluded.contains($0) } == 8)
        queue.remove(id: "a0")
        #expect(queue.remainingCount { excluded.contains($0) } == 7)
    }

    @Test("Il conteggio in modalità manuale conta solo la direzione scelta")
    func remainingCountManual() {
        let queue = SwipeQueue(source: source, startIndex: 3, direction: .towardNewer)
        #expect(queue.remainingCount { _ in false } == 4)
    }

    @Test("Sostituire la sorgente mantiene gli elementi fissati in cima")
    func replaceSource() {
        var queue = SwipeQueue(source: source)
        _ = queue.upcoming(2) { _ in false }
        let newSource = ArraySource(["new"] + source.identifiers)
        queue.replaceSource(newSource, cursor: 0, pinned: [QueueItem(index: 1, id: "a0")])
        let ids = queue.upcoming(4) { _ in false }.map(\.id)
        #expect(ids == ["a0", "new", "a1", "a2"])
    }

    @Test("Una sorgente vuota produce una coda vuota")
    func emptySource() {
        var queue = SwipeQueue(source: ArraySource([]))
        #expect(queue.current { _ in false } == nil)
        #expect(queue.remainingCount { _ in false } == 0)
        queue.reverseDirection { _ in false }
        #expect(queue.current { _ in false } == nil)
    }

    @Test("Un indice di partenza fuori intervallo non provoca crash")
    func outOfRangeStart() {
        var older = SwipeQueue(source: source, startIndex: 50, direction: .towardOlder)
        #expect(older.current { _ in false } == nil)
        var newer = SwipeQueue(source: source, startIndex: 50, direction: .towardNewer)
        #expect(newer.current { _ in false }?.id == "a9")
    }
}
