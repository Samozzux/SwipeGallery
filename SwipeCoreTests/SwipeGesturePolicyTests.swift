import Testing
@testable import SwipeCore

@Suite("Gesto di swipe")
struct SwipeGesturePolicyTests {
    let threshold = SwipeThreshold()
    let width = 400.0

    @Test("Predefinito: sinistra = cestino, destra = tieni")
    func defaultLayout() {
        let layout = SwipeLayout()
        #expect(layout.decision(for: .left) == .trashed)
        #expect(layout.decision(for: .right) == .kept)
        #expect(layout.buttonOrder == [.trash, .undo, .keep])
    }

    @Test("Il lato configurato inverte decisioni e pulsanti")
    func swappedLayout() {
        let layout = SwipeLayout(trashEdge: .right)
        #expect(layout.decision(for: .right) == .trashed)
        #expect(layout.decision(for: .left) == .kept)
        #expect(layout.edge(for: .trashed) == .right)
        #expect(layout.edge(for: .kept) == .left)
        #expect(layout.buttonOrder == [.keep, .undo, .trash])
    }

    @Test("Scatta oltre il 30% della larghezza")
    func distanceThreshold() {
        #expect(threshold.committedEdge(translation: 121, velocity: 0, width: width) == .right)
        #expect(threshold.committedEdge(translation: -121, velocity: 0, width: width) == .left)
        #expect(threshold.committedEdge(translation: 100, velocity: 0, width: width) == nil)
    }

    @Test("Un colpo veloce scatta anche sotto soglia")
    func flick() {
        #expect(threshold.committedEdge(translation: 40, velocity: 1200, width: width) == .right)
        #expect(threshold.committedEdge(translation: -40, velocity: -1200, width: width) == .left)
    }

    @Test("Un colpo veloce in direzione opposta non scatta")
    func flickBack() {
        #expect(threshold.committedEdge(translation: 60, velocity: -1500, width: width) == nil)
    }

    @Test("Un colpo veloce troppo corto non scatta")
    func tinyFlick() {
        #expect(threshold.committedEdge(translation: 5, velocity: 2000, width: width) == nil)
    }

    @Test("Avanzamento e rotazione sono limitati")
    func progressAndRotation() {
        #expect(threshold.progress(translation: 60, width: width) == 0.5)
        #expect(threshold.progress(translation: -1000, width: width) == 1)
        #expect(threshold.rotationDegrees(translation: 200, width: width) == 6)
        #expect(threshold.rotationDegrees(translation: -5000, width: width) == -12)
    }

    @Test("Durata dei video")
    func durations() {
        #expect(DurationFormatting.string(fromSeconds: 7) == "0:07")
        #expect(DurationFormatting.string(fromSeconds: 65.4) == "1:05")
        #expect(DurationFormatting.string(fromSeconds: 3723) == "1:02:03")
        #expect(DurationFormatting.string(fromSeconds: .nan) == "0:00")
    }
}
