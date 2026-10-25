import Foundation

/// Impronta visiva di una foto (feature print di Vision) quantizzata a 8 bit:
/// occupa un quarto della memoria e il confronto per coseno non cambia, perché
/// la scala della quantizzazione si annulla.
public struct FeatureVector: Sendable, Equatable {
    public let components: [Int8]
    private let norm: Float

    /// Quantizza un vettore di float. Restituisce `nil` se è vuoto, nullo o
    /// contiene valori non finiti.
    public init?(floats: [Float]) {
        guard !floats.isEmpty, floats.allSatisfy(\.isFinite) else { return nil }
        let maxAbs = floats.reduce(Float(0)) { max($0, abs($1)) }
        guard maxAbs > 0 else { return nil }
        let scale = 127 / maxAbs
        self.init(quantized: floats.map { Int8(clamping: Int(($0 * scale).rounded())) })
    }

    /// Ricostruisce un vettore già quantizzato (per esempio dalla cache).
    public init?(quantized components: [Int8]) {
        let squares = components.reduce(Int64(0)) { $0 + Int64($1) * Int64($1) }
        guard squares > 0 else { return nil }
        self.components = components
        self.norm = Float(squares).squareRoot()
    }

    public init?(data: Data) {
        self.init(quantized: data.map { Int8(bitPattern: $0) })
    }

    public var data: Data {
        Data(components.map { UInt8(bitPattern: $0) })
    }

    /// Similarità del coseno, da -1 a 1. Vettori di lunghezza diversa
    /// (revisioni diverse del modello) non sono confrontabili: 0.
    public func cosineSimilarity(to other: FeatureVector) -> Float {
        guard components.count == other.components.count else { return 0 }
        var sum: Int32 = 0
        components.withUnsafeBufferPointer { lhs in
            other.components.withUnsafeBufferPointer { rhs in
                for index in 0 ..< lhs.count {
                    sum &+= Int32(lhs[index]) &* Int32(rhs[index])
                }
            }
        }
        return Float(sum) / (norm * other.norm)
    }

    /// Distanza euclidea fra i vettori normalizzati, da 0 (identici) a 2.
    public func distance(to other: FeatureVector) -> Float {
        (max(0, 2 - 2 * cosineSimilarity(to: other))).squareRoot()
    }

    /// Prodotto scalare con un iperpiano, per l'hashing.
    func projection(onto hyperplane: [Float]) -> Float {
        var sum: Float = 0
        components.withUnsafeBufferPointer { values in
            hyperplane.withUnsafeBufferPointer { plane in
                for index in 0 ..< min(values.count, plane.count) {
                    sum += Float(values[index]) * plane[index]
                }
            }
        }
        return sum
    }
}
