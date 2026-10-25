import AVFoundation
import Observation
import Photos
import UIKit

/// Immagine a schermo intero di un asset: prima la versione degradata, poi
/// quella definitiva, con avanzamento del download da iCloud.
@MainActor
@Observable
final class AssetImageModel {
    private(set) var image: UIImage?
    private(set) var isDegraded = true
    /// Avanzamento del download da iCloud; `nil` se non è in corso.
    private(set) var downloadProgress: Double?
    /// Il download dell'originale è fallito: resta visibile la miniatura.
    private(set) var didFail = false

    @ObservationIgnored private var requestID: PHImageRequestID?
    @ObservationIgnored private var loadedID: String?

    func load(_ asset: PHAsset, targetSize: CGSize) {
        guard loadedID != asset.localIdentifier, targetSize.width > 0 else { return }
        cancel()
        loadedID = asset.localIdentifier
        image = nil
        isDegraded = true
        downloadProgress = nil
        didFail = false
        requestID = ImageLoader.shared.requestDisplayImage(for: asset, targetSize: targetSize) { [weak self] event in
            self?.apply(event)
        }
    }

    func cancel() {
        if let requestID {
            ImageLoader.shared.cancel(requestID)
        }
        requestID = nil
        loadedID = nil
        downloadProgress = nil
    }

    private func apply(_ event: DisplayImageEvent) {
        switch event {
        case let .image(newImage, degraded):
            // Una versione degradata in ritardo non deve sostituire quella finale.
            guard isDegraded || !degraded else { return }
            image = newImage
            isDegraded = degraded
            if !degraded {
                downloadProgress = nil
                requestID = nil
            }
        case let .progress(value):
            downloadProgress = value < 1 ? value : nil
        case .failed:
            didFail = true
            downloadProgress = nil
            requestID = nil
        }
    }
}

/// Riproduzione in loop di un video, senza audio finché l'utente non tocca.
@MainActor
@Observable
final class VideoPlaybackModel {
    private(set) var player: AVQueuePlayer?
    private(set) var isMuted = true
    private(set) var isLoading = false

    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var requestID: PHImageRequestID?
    @ObservationIgnored private var loadedID: String?

    func start(_ asset: PHAsset) {
        guard loadedID != asset.localIdentifier else {
            player?.play()
            return
        }
        stop()
        loadedID = asset.localIdentifier
        isLoading = true
        requestID = ImageLoader.shared.requestPlayerItem(for: asset) { [weak self] item in
            self?.didLoad(item, for: asset.localIdentifier)
        }
    }

    func stop() {
        if let requestID {
            ImageLoader.shared.cancel(requestID)
        }
        requestID = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
        loadedID = nil
        isLoading = false
        if !isMuted {
            isMuted = true
            AudioSession.setPlaybackAudible(false)
        }
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
        AudioSession.setPlaybackAudible(!isMuted)
    }

    private func didLoad(_ item: AVPlayerItem?, for id: String) {
        guard loadedID == id else { return }
        requestID = nil
        isLoading = false
        guard let item else { return }
        // Anche un video muto attiva la sessione audio: con la categoria
        // ambient non interrompe la musica in riproduzione.
        AudioSession.setPlaybackAudible(!isMuted)
        let player = AVQueuePlayer()
        player.isMuted = isMuted
        looper = AVPlayerLooper(player: player, templateItem: item)
        self.player = player
        player.play()
    }
}

/// Live Photo da riprodurre con una pressione prolungata.
@MainActor
@Observable
final class LivePhotoModel {
    private(set) var livePhoto: PHLivePhoto?

    @ObservationIgnored private var requestID: PHImageRequestID?
    @ObservationIgnored private var loadedID: String?

    func load(_ asset: PHAsset, targetSize: CGSize) {
        guard loadedID != asset.localIdentifier, targetSize.width > 0 else { return }
        cancel()
        loadedID = asset.localIdentifier
        requestID = ImageLoader.shared.requestLivePhoto(for: asset, targetSize: targetSize) { [weak self] livePhoto in
            guard let self, self.loadedID == asset.localIdentifier else { return }
            self.livePhoto = livePhoto
            self.requestID = nil
        }
    }

    func cancel() {
        if let requestID {
            ImageLoader.shared.cancel(requestID)
        }
        requestID = nil
        loadedID = nil
        livePhoto = nil
    }
}

/// Categoria audio: i video partono muti e non interrompono la musica; quando
/// l'utente attiva l'audio si passa alla riproduzione vera e propria.
@MainActor
enum AudioSession {
    static func setPlaybackAudible(_ audible: Bool) {
        let session = AVAudioSession.sharedInstance()
        if audible {
            try? session.setCategory(.playback, mode: .moviePlayback)
        } else {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
    }
}
