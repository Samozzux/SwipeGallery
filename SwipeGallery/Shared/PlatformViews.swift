import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Superficie di riproduzione video senza controlli: i tocchi passano a
/// SwiftUI (swipe e attivazione dell'audio).
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

/// Live Photo che si riproduce con la pressione prolungata nativa di
/// `PHLivePhotoView`.
struct LivePhotoSurface: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.livePhoto = livePhoto
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        if view.livePhoto !== livePhoto {
            view.livePhoto = livePhoto
        }
    }
}

/// Ponte verso le API UIKit che SwiftUI non espone.
@MainActor
enum SystemActions {
    static var settingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    /// Apre l'app Foto. Lo schema non è documentato ma è quello usato dal
    /// sistema; se smettesse di funzionare il pulsante non fa nulla.
    static var photosAppURL: URL? {
        URL(string: "photos-redirect://")
    }

    /// Evita lo spegnimento dello schermo durante le analisi lunghe.
    static func setKeepScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    /// Mostra il selettore di sistema per modificare la selezione con
    /// accesso limitato.
    static func presentLimitedLibraryPicker() {
        guard let controller = topViewController() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
