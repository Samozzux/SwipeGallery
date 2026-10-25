import Foundation
import Photos
import SwipeCore
import UIKit
import Vision

/// Flag di annullamento condiviso fra l'interfaccia e la coda di analisi.
final class ScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}

/// Calcola l'impronta visiva (feature print di Vision) di ogni foto, sul
/// dispositivo e senza rete, partendo da una miniatura.
///
/// Tutto il codice qui è volutamente fuori dal MainActor: PhotoKit e Vision
/// vengono chiamati in modo sincrono su una coda dedicata, così non occupano i
/// thread di Swift Concurrency e le closure passate a PhotoKit non ereditano
/// l'isolamento del main thread.
enum SimilarityScanner {
    struct Progress: Sendable {
        let done: Int
        let total: Int
    }

    /// Lato lungo della miniatura analizzata, in pixel.
    private static let thumbnailSide: CGFloat = 360
    /// Ogni quante foto nuove salvare la cache, per non perdere il lavoro se
    /// l'app viene chiusa durante la prima analisi.
    private static let saveInterval = 500

    /// Analizza `assets` (ordinati per data) e restituisce le foto con la loro
    /// impronta. Se l'analisi viene annullata restituisce quelle elaborate.
    static func analyze(
        _ assets: PHFetchResult<PHAsset>,
        cancellation: ScanCancellation,
        progress: @escaping @Sendable (Progress) -> Void
    ) async -> [SimilarityItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let items = analyzeSynchronously(assets, cancellation: cancellation, progress: progress)
                continuation.resume(returning: items)
            }
        }
    }

    private static func analyzeSynchronously(
        _ assets: PHFetchResult<PHAsset>,
        cancellation: ScanCancellation,
        progress: @Sendable (Progress) -> Void
    ) -> [SimilarityItem] {
        var cache = FeaturePrintCache.load()
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        let total = assets.count
        var items: [SimilarityItem] = []
        items.reserveCapacity(total)
        var seen = Set<String>()
        var unsaved = 0

        for index in 0 ..< total {
            if cancellation.isCancelled { break }
            autoreleasepool {
                let asset = assets.object(at: index)
                let id = asset.localIdentifier
                seen.insert(id)
                var vector = cache[id]
                if vector == nil, let computed = featureVector(for: asset, manager: manager, options: options) {
                    vector = computed
                    cache[id] = computed
                    unsaved += 1
                }
                if let vector {
                    items.append(SimilarityItem(id: id, date: asset.creationDate, vector: vector))
                }
            }
            if index % 25 == 0 || index == total - 1 {
                progress(Progress(done: index + 1, total: total))
            }
            if unsaved >= saveInterval {
                try? cache.save()
                unsaved = 0
            }
        }

        if !cancellation.isCancelled {
            cache.prune(keeping: seen)
        }
        try? cache.save()
        return items
    }

    private static func featureVector(
        for asset: PHAsset,
        manager: PHImageManager,
        options: PHImageRequestOptions
    ) -> FeatureVector? {
        // Con `isSynchronous` l'handler viene chiamato una volta sola, prima
        // che `requestImage` ritorni.
        let result = ThumbnailBox()
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: thumbnailSide, height: thumbnailSide),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            result.image = image
        }
        guard let thumbnail = result.image, let cgImage = thumbnail.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(thumbnail.imageOrientation),
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }
        return FeatureVector(observation)
    }
}

/// Contenitore per il risultato della richiesta sincrona di PhotoKit.
private final class ThumbnailBox: @unchecked Sendable {
    var image: UIImage?
}

private extension FeatureVector {
    init?(_ observation: VNFeaturePrintObservation) {
        let count = observation.elementCount
        let data = observation.data
        let floats: [Float]
        switch observation.elementType {
        case .float:
            guard data.count >= count * MemoryLayout<Float>.size else { return nil }
            floats = data.withUnsafeBytes { raw in
                (0 ..< count).map { raw.loadUnaligned(fromByteOffset: $0 * MemoryLayout<Float>.size, as: Float.self) }
            }
        case .double:
            guard data.count >= count * MemoryLayout<Double>.size else { return nil }
            floats = data.withUnsafeBytes { raw in
                (0 ..< count).map { Float(raw.loadUnaligned(fromByteOffset: $0 * MemoryLayout<Double>.size, as: Double.self)) }
            }
        default:
            return nil
        }
        self.init(floats: floats)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
