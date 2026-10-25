import Foundation
import Testing
@testable import SwipeCore

@Suite("Foto simili")
struct SimilarityGrouperTests {
    let dimension = 256
    let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// Vettore casuale ma deterministico.
    func randomFloats(seed: UInt64) -> [Float] {
        var generator = SplitMix64(seed: seed)
        return (0 ..< dimension).map { _ in generator.nextGaussian() }
    }

    /// Copia di `floats` con un rumore di ampiezza `amount`.
    func perturbed(_ floats: [Float], amount: Float, seed: UInt64) -> [Float] {
        var generator = SplitMix64(seed: seed)
        return floats.map { $0 + amount * generator.nextGaussian() }
    }

    func item(_ id: String, _ floats: [Float], minutes: Double?) -> SimilarityItem {
        SimilarityItem(
            id: id,
            date: minutes.map { base.addingTimeInterval($0 * 60) },
            vector: FeatureVector(floats: floats)!
        )
    }

    @Test("La quantizzazione conserva la similarità")
    func quantization() {
        let a = randomFloats(seed: 1)
        let b = perturbed(a, amount: 0.05, seed: 2)
        let vectorA = FeatureVector(floats: a)!
        let vectorB = FeatureVector(floats: b)!
        #expect(vectorA.distance(to: vectorA) < 0.001)
        #expect(vectorA.distance(to: vectorB) < 0.12)
        let unrelated = FeatureVector(floats: randomFloats(seed: 3))!
        #expect(vectorA.distance(to: unrelated) > 1.2)
        #expect(FeatureVector(data: vectorA.data) == vectorA)
    }

    @Test("Vettori non validi vengono rifiutati")
    func invalidVectors() {
        #expect(FeatureVector(floats: []) == nil)
        #expect(FeatureVector(floats: [0, 0, 0]) == nil)
        #expect(FeatureVector(floats: [1, .nan]) == nil)
        let short = FeatureVector(floats: [1, 2])!
        let long = FeatureVector(floats: [1, 2, 3])!
        #expect(short.cosineSimilarity(to: long) == 0)
    }

    @Test("Scatti ravvicinati e simili finiscono nello stesso gruppo")
    func burstGroup() {
        let scene = randomFloats(seed: 10)
        let items = [
            item("a", scene, minutes: 0),
            item("b", perturbed(scene, amount: 0.1, seed: 11), minutes: 0.2),
            item("c", perturbed(scene, amount: 0.1, seed: 12), minutes: 0.5),
            item("x", randomFloats(seed: 13), minutes: 1),
        ]
        let groups = SimilarityGrouper.groups(items, options: .preset(.balanced))
        #expect(groups == [[0, 1, 2]])
    }

    @Test("Foto simili ma lontane nel tempo non vengono raggruppate")
    func similarButFarApart() {
        let scene = randomFloats(seed: 20)
        let items = [
            item("a", scene, minutes: 0),
            item("b", perturbed(scene, amount: 0.25, seed: 21), minutes: 60 * 24),
        ]
        let groups = SimilarityGrouper.groups(items, options: .preset(.balanced))
        #expect(groups.isEmpty)
    }

    @Test("I doppioni quasi identici si trovano anche lontani nel tempo")
    func duplicatesFarApart() {
        let photo = randomFloats(seed: 30)
        var items = [item("original", photo, minutes: 0)]
        for index in 0 ..< 40 {
            items.append(item("other\(index)", randomFloats(seed: 100 + UInt64(index)), minutes: Double(10 + index * 30)))
        }
        items.append(item("copy", perturbed(photo, amount: 0.01, seed: 31), minutes: 60 * 24 * 90))
        let groups = SimilarityGrouper.groups(items, options: .preset(.balanced))
        #expect(groups == [[0, items.count - 1]])
    }

    @Test("Il raggruppamento è transitivo e i gruppi vanno dal più recente")
    func transitiveAndOrdered() {
        let scene = randomFloats(seed: 40)
        let step1 = perturbed(scene, amount: 0.12, seed: 41)
        let step2 = perturbed(step1, amount: 0.12, seed: 42)
        let other = randomFloats(seed: 43)
        let items = [
            item("old1", other, minutes: 0),
            item("old2", perturbed(other, amount: 0.05, seed: 44), minutes: 1),
            item("new1", scene, minutes: 600),
            item("new2", step1, minutes: 601),
            item("new3", step2, minutes: 602),
        ]
        let groups = SimilarityGrouper.groups(items, options: .preset(.balanced))
        #expect(groups == [[2, 3, 4], [0, 1]])
    }

    @Test("Una sensibilità più stretta produce meno raggruppamenti")
    func sensitivity() {
        let scene = randomFloats(seed: 50)
        let items = [
            item("a", scene, minutes: 0),
            item("b", perturbed(scene, amount: 0.35, seed: 51), minutes: 1),
        ]
        let distance = items[0].vector.distance(to: items[1].vector)
        let strict = SimilarityGrouper.groups(items, options: .preset(.strict))
        let loose = SimilarityGrouper.groups(items, options: .preset(.loose))
        #expect(distance > SimilarityOptions.preset(.strict).similarDistance)
        #expect(distance <= SimilarityOptions.preset(.loose).similarDistance)
        #expect(strict.isEmpty)
        #expect(loose == [[0, 1]])
    }

    @Test("Meno di due foto non producono gruppi")
    func tooFewItems() {
        #expect(SimilarityGrouper.groups([], options: .preset(.balanced)).isEmpty)
        #expect(SimilarityGrouper.groups([item("a", randomFloats(seed: 60), minutes: 0)], options: .preset(.balanced)).isEmpty)
    }

    @Test("La foto suggerita privilegia preferite, modifiche e risoluzione")
    func bestShot() {
        let date = Date(timeIntervalSince1970: 0)
        let plain = ShotCandidate(id: "plain", pixelCount: 12_000_000, isFavorite: false, isEdited: false, date: date)
        let small = ShotCandidate(id: "small", pixelCount: 3_000_000, isFavorite: false, isEdited: false, date: date)
        let edited = ShotCandidate(id: "edited", pixelCount: 3_000_000, isFavorite: false, isEdited: true, date: date)
        let favorite = ShotCandidate(id: "favorite", pixelCount: 1_000_000, isFavorite: true, isEdited: false, date: date)
        #expect(BestShot.bestIndex([small, plain]) == 1)
        #expect(BestShot.bestIndex([plain, edited]) == 1)
        #expect(BestShot.bestIndex([edited, favorite, plain]) == 1)
        #expect(BestShot.bestIndex([]) == nil)
    }
}
