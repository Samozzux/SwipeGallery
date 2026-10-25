import Foundation

/// Una foto da confrontare: identificatore, data di scatto e impronta visiva.
public struct SimilarityItem: Sendable, Equatable {
    public let id: String
    public let date: Date?
    public let vector: FeatureVector

    public init(id: String, date: Date?, vector: FeatureVector) {
        self.id = id
        self.date = date
        self.vector = vector
    }
}

/// Quanto devono assomigliarsi due foto per finire nello stesso gruppo.
public enum SimilaritySensitivity: Int, CaseIterable, Sendable {
    /// Solo foto quasi identiche.
    case strict
    case balanced
    /// Anche scatti della stessa scena con differenze evidenti.
    case loose
}

/// Parametri del raggruppamento. Le distanze sono fra vettori normalizzati
/// (0 = identici, 2 = opposti).
public struct SimilarityOptions: Sendable, Equatable {
    /// Soglia per foto scattate a breve distanza di tempo.
    public var similarDistance: Float
    /// Soglia, più stretta, per doppioni in qualsiasi punto della libreria.
    public var duplicateDistance: Float
    /// Due foto sono "vicine nel tempo" se scattate entro questo intervallo.
    public var timeWindow: TimeInterval
    /// Quante foto successive confrontare al massimo per ogni foto.
    public var maxNeighbors: Int
    /// Tabelle e bit dell'hashing per trovare i doppioni lontani nel tempo.
    public var hashTables: Int
    public var hashBits: Int
    /// Oltre questa dimensione un bucket viene confrontato solo fra elementi
    /// vicini, per evitare costi quadratici.
    public var maxFullBucket: Int

    public init(
        similarDistance: Float,
        duplicateDistance: Float,
        timeWindow: TimeInterval = 10 * 60,
        maxNeighbors: Int = 15,
        hashTables: Int = 3,
        hashBits: Int = 10,
        maxFullBucket: Int = 200
    ) {
        self.similarDistance = similarDistance
        self.duplicateDistance = duplicateDistance
        self.timeWindow = timeWindow
        self.maxNeighbors = maxNeighbors
        self.hashTables = hashTables
        self.hashBits = hashBits
        self.maxFullBucket = maxFullBucket
    }

    public static func preset(_ sensitivity: SimilaritySensitivity) -> SimilarityOptions {
        switch sensitivity {
        case .strict: SimilarityOptions(similarDistance: 0.28, duplicateDistance: 0.12)
        case .balanced: SimilarityOptions(similarDistance: 0.38, duplicateDistance: 0.15)
        case .loose: SimilarityOptions(similarDistance: 0.48, duplicateDistance: 0.18)
        }
    }
}

/// Raggruppa foto doppie o simili senza confrontare ogni coppia della libreria:
/// 1. ogni foto con quelle scattate subito dopo (raffiche, scatti ripetuti);
/// 2. doppioni quasi identici ovunque, tramite hashing su iperpiani casuali
///    (vettori molto vicini finiscono quasi sempre nello stesso bucket).
public enum SimilarityGrouper {
    /// Gruppi di indici in `items` con almeno due elementi. Ogni gruppo è
    /// ordinato per data di scatto; i gruppi dal più recente.
    public static func groups(_ items: [SimilarityItem], options: SimilarityOptions) -> [[Int]] {
        guard items.count > 1 else { return [] }
        var sets = UnionFind(count: items.count)

        // Indici ordinati per data; le foto senza data restano fuori dal
        // confronto temporale.
        let dated = items.indices
            .filter { items[$0].date != nil }
            .sorted { items[$0].date! < items[$1].date! }

        for (position, lhs) in dated.enumerated() {
            let lhsDate = items[lhs].date!
            var next = position + 1
            while next < dated.count, next - position <= options.maxNeighbors {
                let rhs = dated[next]
                if items[rhs].date!.timeIntervalSince(lhsDate) > options.timeWindow { break }
                if items[lhs].vector.distance(to: items[rhs].vector) <= options.similarDistance {
                    sets.union(lhs, rhs)
                }
                next += 1
            }
        }

        linkDuplicates(items, order: dated + items.indices.filter { items[$0].date == nil }, options: options, sets: &sets)

        var members: [Int: [Int]] = [:]
        for index in items.indices {
            members[sets.find(index), default: []].append(index)
        }
        return members.values
            .filter { $0.count > 1 }
            .map { group in group.sorted { (items[$0].date ?? .distantPast) < (items[$1].date ?? .distantPast) } }
            .sorted { lhs, rhs in
                let lhsDate = lhs.compactMap { items[$0].date }.max() ?? .distantPast
                let rhsDate = rhs.compactMap { items[$0].date }.max() ?? .distantPast
                return lhsDate != rhsDate ? lhsDate > rhsDate : items[lhs[0]].id < items[rhs[0]].id
            }
    }

    private static func linkDuplicates(
        _ items: [SimilarityItem],
        order: [Int],
        options: SimilarityOptions,
        sets: inout UnionFind
    ) {
        guard options.hashTables > 0, options.hashBits > 0 else { return }
        let dimension = items[0].vector.components.count
        var generator = SplitMix64(seed: 0x5EED_5A1E)
        for _ in 0 ..< options.hashTables {
            let planes = (0 ..< options.hashBits).map { _ in
                (0 ..< dimension).map { _ in generator.nextGaussian() }
            }
            var buckets: [UInt32: [Int]] = [:]
            for index in order where items[index].vector.components.count == dimension {
                var key: UInt32 = 0
                for (bit, plane) in planes.enumerated() where items[index].vector.projection(onto: plane) >= 0 {
                    key |= 1 << UInt32(bit)
                }
                buckets[key, default: []].append(index)
            }
            for bucket in buckets.values where bucket.count > 1 {
                let span = bucket.count <= options.maxFullBucket ? bucket.count : options.maxNeighbors
                for position in bucket.indices {
                    let upper = min(position + span, bucket.count - 1)
                    guard position < upper else { continue }
                    for other in (position + 1) ... upper {
                        let lhs = bucket[position]
                        let rhs = bucket[other]
                        if sets.find(lhs) != sets.find(rhs),
                           items[lhs].vector.distance(to: items[rhs].vector) <= options.duplicateDistance {
                            sets.union(lhs, rhs)
                        }
                    }
                }
            }
        }
    }
}

/// Dati di una foto per scegliere quale tenere in un gruppo.
public struct ShotCandidate: Sendable, Equatable {
    public let id: String
    public let pixelCount: Int
    public let isFavorite: Bool
    public let isEdited: Bool
    public let date: Date?

    public init(id: String, pixelCount: Int, isFavorite: Bool, isEdited: Bool, date: Date?) {
        self.id = id
        self.pixelCount = pixelCount
        self.isFavorite = isFavorite
        self.isEdited = isEdited
        self.date = date
    }
}

public enum BestShot {
    /// Foto suggerita da tenere: preferita, poi modificata, poi con più pixel,
    /// poi la più recente.
    public static func bestIndex(_ candidates: [ShotCandidate]) -> Int? {
        candidates.indices.max { lhs, rhs in
            let a = candidates[lhs]
            let b = candidates[rhs]
            if a.isFavorite != b.isFavorite { return !a.isFavorite }
            if a.isEdited != b.isEdited { return !a.isEdited }
            if a.pixelCount != b.pixelCount { return a.pixelCount < b.pixelCount }
            let aDate = a.date ?? .distantPast
            let bDate = b.date ?? .distantPast
            if aDate != bDate { return aDate < bDate }
            return a.id > b.id
        }
    }
}

// MARK: - Supporto

struct UnionFind {
    private var parent: [Int]
    private var rank: [UInt8]

    init(count: Int) {
        parent = Array(0 ..< count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ element: Int) -> Int {
        var root = element
        while parent[root] != root {
            root = parent[root]
        }
        var current = element
        while parent[current] != root {
            let next = parent[current]
            parent[current] = root
            current = next
        }
        return root
    }

    mutating func union(_ lhs: Int, _ rhs: Int) {
        let a = find(lhs)
        let b = find(rhs)
        guard a != b else { return }
        if rank[a] < rank[b] {
            parent[a] = b
        } else if rank[a] > rank[b] {
            parent[b] = a
        } else {
            parent[b] = a
            rank[a] += 1
        }
    }
}

/// Generatore deterministico: gli iperpiani sono sempre gli stessi, così i
/// risultati non cambiano fra un'analisi e l'altra.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Valore in (0, 1].
    mutating func nextUnit() -> Float {
        Float(next() >> 40 + 1) / Float(1 << 24)
    }

    /// Distribuzione normale standard (Box-Muller).
    mutating func nextGaussian() -> Float {
        let u1 = nextUnit()
        let u2 = nextUnit()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
