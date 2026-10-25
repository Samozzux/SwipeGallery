import Foundation
import Observation
import SwiftData
import SwipeCore

/// Persistenza delle decisioni (SwiftData) con una copia in memoria
/// (`DecisionIndex`) per filtrare le code senza interrogare il database.
@MainActor
@Observable
final class DecisionStore {
    private(set) var index = DecisionIndex()
    /// Aumenta a ogni modifica.
    private(set) var revision = 0
    /// Aumenta quando degli elementi tornano "da valutare" fuori dal flusso di
    /// swipe (ripristino dal cestino, azzera progresso): le code predefinite
    /// devono ripartire dall'inizio per riproporli.
    private(set) var resetGeneration = 0

    @ObservationIgnored private let context: ModelContext

    /// I batch delete usano `IN (...)`: si resta sotto il limite di variabili
    /// di SQLite.
    private static let deleteChunkSize = 500

    init(context: ModelContext) {
        self.context = context
        load()
    }

    func decision(for id: String) -> Decision? {
        index.decision(for: id)
    }

    /// Imposta o rimuove (con `nil`) la decisione per un elemento.
    func setDecision(_ decision: Decision?, for id: String) {
        let now = Date.now
        if let existing = record(for: id) {
            if let decision {
                existing.decision = decision
                existing.decidedAt = now
            } else {
                context.delete(existing)
            }
        } else if let decision {
            context.insert(AssetDecision(localIdentifier: id, decision: decision, decidedAt: now))
        }
        save()
        index.set(decision, for: id, at: now)
        revision += 1
    }

    /// Ripristina elementi dal cestino: tornano "da valutare".
    func restore(_ ids: some Collection<String>) {
        guard !ids.isEmpty else { return }
        deleteRecords(Array(ids))
        index.remove(ids)
        revision += 1
        resetGeneration += 1
    }

    /// "Azzera progresso": rimuove tutte le decisioni "tenuto", non tocca il cestino.
    func resetKept() {
        let kept = Decision.kept.rawValue
        do {
            try context.delete(model: AssetDecision.self, where: #Predicate { $0.decisionRawValue == kept })
        } catch {
            deleteRecords(Array(index.keptIDs))
        }
        save()
        index.removeAllKept()
        revision += 1
        resetGeneration += 1
    }

    /// Dimentica i record di elementi che non esistono più nella libreria
    /// (eliminati dall'app o altrove). Non riporta nulla "da valutare".
    func forget(_ ids: some Collection<String>) {
        let known = ids.filter { index.isDecided($0) }
        guard !known.isEmpty else { return }
        deleteRecords(known)
        index.remove(known)
        revision += 1
    }

    // MARK: - Privato

    private func load() {
        let records = (try? context.fetch(FetchDescriptor<AssetDecision>())) ?? []
        index = DecisionIndex(entries: records.map {
            (id: $0.localIdentifier, decision: $0.decision, date: $0.decidedAt)
        })
    }

    private func record(for id: String) -> AssetDecision? {
        var descriptor = FetchDescriptor<AssetDecision>(predicate: #Predicate { $0.localIdentifier == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func deleteRecords(_ ids: [String]) {
        var start = 0
        while start < ids.count {
            let chunk = Array(ids[start ..< min(start + Self.deleteChunkSize, ids.count)])
            try? context.delete(model: AssetDecision.self, where: #Predicate { chunk.contains($0.localIdentifier) })
            start += Self.deleteChunkSize
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Salvataggio delle decisioni non riuscito: \(error)")
        }
    }
}
