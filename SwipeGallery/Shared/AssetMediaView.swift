import Photos
import SwiftUI

/// Contenuto a schermo intero di un elemento: immagine (prima degradata poi
/// definitiva), video in loop o Live Photo. Video e Live Photo partono solo
/// sulla card attiva.
struct AssetMediaView: View {
    let asset: PHAsset
    let isActive: Bool
    /// Dimensione in pixel, uguale a quella del precaricamento.
    let targetSize: CGSize
    let video: VideoPlaybackModel

    @State private var imageModel = AssetImageModel()
    @State private var live = LivePhotoModel()

    private var kind: AssetKind { AssetKind(asset) }

    /// Il modello video sta riproducendo proprio questo elemento (lo stesso
    /// modello può passare da una card all'altra).
    private var ownsVideo: Bool {
        isActive && kind == .video && video.loadedID == asset.localIdentifier
    }

    var body: some View {
        ZStack {
            if let image = imageModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if !imageModel.didFail {
                ProgressView()
                    .controlSize(.large)
            }

            if isActive, kind == .livePhoto, let livePhoto = live.livePhoto {
                LivePhotoSurface(livePhoto: livePhoto)
            }

            if ownsVideo, let player = video.player {
                PlayerSurface(player: player)
            }

            if kind == .video {
                if ownsVideo {
                    if let progress = video.downloadProgress {
                        DownloadProgressBadge(progress: progress)
                    } else if video.isLoading || (video.isBuffering && !video.isPaused && !video.isScrubbing) {
                        VideoLoadingBadge()
                    }
                }
            } else if let progress = imageModel.downloadProgress {
                DownloadProgressBadge(progress: progress)
            }

            if imageModel.didFail || (ownsVideo && video.didFail) {
                VStack {
                    Spacer()
                    Label(
                        kind == .video ? "Video non disponibile da iCloud" : "Originale non disponibile da iCloud",
                        systemImage: "exclamationmark.icloud"
                    )
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 110)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            load()
        }
        .onChange(of: targetSize) {
            load()
        }
        .onChange(of: isActive) {
            updatePlayback()
        }
        .onDisappear {
            imageModel.cancel()
            live.cancel()
            video.stop(asset.localIdentifier)
        }
    }

    private func load() {
        imageModel.load(asset, targetSize: targetSize)
        updatePlayback()
    }

    private func updatePlayback() {
        switch kind {
        case .video:
            if isActive {
                video.start(asset)
            } else {
                video.stop(asset.localIdentifier)
            }
        case .livePhoto:
            if isActive {
                live.load(asset, targetSize: targetSize)
            }
        case .photo, .screenshot:
            break
        }
    }
}

/// Caricamento o buffering di un video. Compare con un attimo di ritardo, così
/// non lampeggia per i video che partono subito.
struct VideoLoadingBadge: View {
    @State private var isVisible = false

    var body: some View {
        Label {
            Text("Caricamento video…")
        } icon: {
            ProgressView()
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeIn(duration: 0.2), value: isVisible)
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            isVisible = true
        }
    }
}

/// Avanzamento del download dell'originale da iCloud.
struct DownloadProgressBadge: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(progress, 0.02))
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            }
            .frame(width: 36, height: 36)
            Text("Download da iCloud… \(Int(progress * 100))%")
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
