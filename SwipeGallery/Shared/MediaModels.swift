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
    private(set) var player: AVPlayer?
    private(set) var isMuted = true
    /// Il video sta arrivando da PhotoKit (eventualmente da iCloud).
    private(set) var isLoading = false
    /// Avanzamento del download da iCloud; `nil` se non è in corso.
    private(set) var downloadProgress: Double?
    /// La riproduzione è ferma in attesa di dati.
    private(set) var isBuffering = false
    private(set) var didFail = false

    @ObservationIgnored private var token: VideoLoadToken?
    @ObservationIgnored private var loadedID: String?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?

    func start(_ asset: PHAsset) {
        guard loadedID != asset.localIdentifier else {
            player?.play()
            return
        }
        stop()
        let id = asset.localIdentifier
        loadedID = id
        isLoading = true
        token = ImageLoader.shared.loadVideo(asset) { [weak self] event in
            self?.handle(event, for: id)
        }
    }

    func stop() {
        if let token {
            ImageLoader.shared.cancelVideoLoad(token)
        }
        token = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
        loadedID = nil
        isLoading = false
        isBuffering = false
        downloadProgress = nil
        didFail = false
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

    private func handle(_ event: VideoLoadEvent, for id: String) {
        guard loadedID == id else { return }
        switch event {
        case let .progress(value):
            downloadProgress = value < 1 ? value : nil
        case let .ready(item):
            token = nil
            isLoading = false
            downloadProgress = nil
            play(item)
        case .failed:
            token = nil
            isLoading = false
            downloadProgress = nil
            didFail = true
        }
    }

    private func play(_ item: AVPlayerItem) {
        // Anche un video muto attiva la sessione audio: con la categoria
        // ambient non interrompe la musica in riproduzione.
        AudioSession.setPlaybackAudible(!isMuted)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        // Il loop riavvolge lo stesso item: nulla da riscaricare a ogni giro.
        player.actionAtItemEnd = .none
        // Le closure passate ad AVFoundation sono esplicitamente @Sendable:
        // possono essere chiamate fuori dal main thread.
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { @Sendable [weak self] _ in
            Task { @MainActor in
                self?.restartFromBeginning()
            }
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { @Sendable [weak self] _, change in
            let waiting = change.newValue == .waitingToPlayAtSpecifiedRate
            Task { @MainActor in
                self?.isBuffering = waiting
            }
        }
        self.player = player
        player.play()
    }

    private func restartFromBeginning() {
        guard let player else { return }
        player.seek(to: .zero)
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
    /// Stato attuale: riconfigurare la sessione è un'operazione lenta, si
    /// evita di ripeterla a ogni video.
    private static var isAudible: Bool?

    static func setPlaybackAudible(_ audible: Bool) {
        guard isAudible != audible else { return }
        isAudible = audible
        let session = AVAudioSession.sharedInstance()
        if audible {
            try? session.setCategory(.playback, mode: .moviePlayback)
        } else {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
    }
}
