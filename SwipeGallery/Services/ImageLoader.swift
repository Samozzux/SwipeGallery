import AVFoundation
import Photos
import UIKit

/// Evento di caricamento di un'immagine a schermo intero.
enum DisplayImageEvent {
    /// Prima arriva una versione a bassa qualità (`isDegraded`), poi quella definitiva.
    case image(UIImage, isDegraded: Bool)
    /// Avanzamento del download da iCloud, da 0 a 1.
    case progress(Double)
    case failed
}

/// Caricamento di immagini, Live Photo e video da PhotoKit, con precaricamento
/// degli elementi successivi della coda.
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()

    private let manager = PHCachingImageManager()
    private var cachedDeckAssets: [PHAsset] = []
    private var cachedDeckSize: CGSize = .zero

    private init() {}

    // MARK: - Immagini a schermo intero

    /// Le opzioni di precaricamento devono coincidere con quelle della
    /// richiesta, altrimenti la cache non viene usata.
    private func displayOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.version = .current
        options.isNetworkAccessAllowed = true
        return options
    }

    /// Precarica alla risoluzione dello schermo gli elementi indicati e smette
    /// di precaricare quelli non più necessari.
    func updateDeckCache(_ assets: [PHAsset], targetSize: CGSize) {
        guard targetSize.width > 0, targetSize.height > 0 else { return }
        if targetSize != cachedDeckSize {
            manager.stopCachingImagesForAllAssets()
            cachedDeckAssets = []
            cachedDeckSize = targetSize
        }
        let incoming = Set(assets.map(\.localIdentifier))
        let cached = Set(cachedDeckAssets.map(\.localIdentifier))
        let toStop = cachedDeckAssets.filter { !incoming.contains($0.localIdentifier) }
        let toStart = assets.filter { !cached.contains($0.localIdentifier) }
        if !toStop.isEmpty {
            manager.stopCachingImages(for: toStop, targetSize: targetSize, contentMode: .aspectFit, options: displayOptions())
        }
        if !toStart.isEmpty {
            manager.startCachingImages(for: toStart, targetSize: targetSize, contentMode: .aspectFit, options: displayOptions())
        }
        cachedDeckAssets = assets
    }

    /// Richiede l'immagine a schermo intero. `handler` può essere chiamato più
    /// volte: versione degradata, avanzamento del download, versione finale.
    @discardableResult
    func requestDisplayImage(
        for asset: PHAsset,
        targetSize: CGSize,
        handler: @escaping @MainActor @Sendable (DisplayImageEvent) -> Void
    ) -> PHImageRequestID {
        let options = displayOptions()
        options.progressHandler = { @Sendable progress, _, _, _ in
            Task { @MainActor in
                handler(.progress(progress))
            }
        }
        return manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { @Sendable image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let box = UncheckedSendable(image)
            Task { @MainActor in
                if let image = box.value {
                    handler(.image(image, isDegraded: isDegraded))
                } else if !isCancelled {
                    handler(.failed)
                }
            }
        }
    }

    func cancel(_ requestID: PHImageRequestID) {
        manager.cancelImageRequest(requestID)
    }

    // MARK: - Miniature

    /// Miniatura per le griglie. Restituisce `nil` se il task viene annullato.
    func thumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let request = ThumbnailRequest()
        let manager = self.manager
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard request.install(continuation) else { return }
                let requestID = manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { @Sendable image, info in
                    if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                    request.finish(UncheckedSendable(image))
                }
                request.setRequestID(requestID)
            }
        } onCancel: {
            if let requestID = request.cancel() {
                manager.cancelImageRequest(requestID)
            }
        }
        return result.value
    }

    // MARK: - Live Photo e video

    @discardableResult
    func requestLivePhoto(
        for asset: PHAsset,
        targetSize: CGSize,
        handler: @escaping @MainActor @Sendable (PHLivePhoto) -> Void
    ) -> PHImageRequestID {
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return manager.requestLivePhoto(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { @Sendable livePhoto, _ in
            guard let livePhoto else { return }
            Task { @MainActor in
                handler(livePhoto)
            }
        }
    }

    @discardableResult
    func requestPlayerItem(
        for asset: PHAsset,
        handler: @escaping @MainActor @Sendable (AVPlayerItem?) -> Void
    ) -> PHImageRequestID {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        return manager.requestPlayerItem(forVideo: asset, options: options) { @Sendable item, _ in
            let box = UncheckedSendable(item)
            Task { @MainActor in
                handler(box.value)
            }
        }
    }
}

/// Stato di una richiesta di miniatura: garantisce che la continuation venga
/// ripresa una sola volta, anche se PhotoKit non chiama mai l'handler dopo
/// un annullamento.
private final class ThumbnailRequest: @unchecked Sendable {
    typealias Continuation = CheckedContinuation<UncheckedSendable<UIImage?>, Never>

    private let lock = NSLock()
    private var continuation: Continuation?
    private var requestID: PHImageRequestID?
    private var isDone = false

    /// Restituisce `false` se la richiesta è già stata annullata.
    func install(_ continuation: Continuation) -> Bool {
        let accepted = lock.withLock {
            guard !isDone else { return false }
            self.continuation = continuation
            return true
        }
        if !accepted {
            continuation.resume(returning: UncheckedSendable(nil))
        }
        return accepted
    }

    func setRequestID(_ requestID: PHImageRequestID) {
        lock.withLock {
            self.requestID = requestID
        }
    }

    func finish(_ image: UncheckedSendable<UIImage?>) {
        takeContinuation()?.resume(returning: image)
    }

    /// Annulla e restituisce l'id della richiesta PhotoKit, se presente.
    func cancel() -> PHImageRequestID? {
        let requestID = lock.withLock { self.requestID }
        takeContinuation()?.resume(returning: UncheckedSendable(nil))
        return requestID
    }

    private func takeContinuation() -> Continuation? {
        lock.withLock {
            guard !isDone else { return nil }
            isDone = true
            defer { continuation = nil }
            return continuation
        }
    }
}
