import Foundation
import SwipeCore

/// Impronte visive già calcolate, salvate in Caches: le analisi successive
/// elaborano solo le foto nuove. Se iOS svuota la cache, l'analisi riparte da
/// zero senza perdere nulla di importante.
struct FeaturePrintCache {
    private(set) var vectors: [String: FeatureVector] = [:]

    static var fileURL: URL {
        URL.cachesDirectory.appending(path: "featureprints-v1.plist")
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    static func load() -> FeaturePrintCache {
        var cache = FeaturePrintCache()
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Data]
        else { return cache }
        cache.vectors.reserveCapacity(stored.count)
        for (id, bytes) in stored {
            cache.vectors[id] = FeatureVector(data: bytes)
        }
        return cache
    }

    func save() throws {
        let stored = vectors.mapValues(\.data)
        let data = try PropertyListSerialization.data(fromPropertyList: stored, format: .binary, options: 0)
        try data.write(to: Self.fileURL, options: .atomic)
    }

    subscript(id: String) -> FeatureVector? {
        get { vectors[id] }
        set { vectors[id] = newValue }
    }

    /// Dimentica le foto che non esistono più.
    mutating func prune(keeping ids: Set<String>) {
        vectors = vectors.filter { ids.contains($0.key) }
    }
}
