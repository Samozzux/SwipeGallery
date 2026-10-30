import SwiftUI

/// Stato dello zoom della foto in cima alla pila.
struct ZoomState: Equatable {
    var scale: CGFloat = 1
    var committedScale: CGFloat = 1
    var offset: CGSize = .zero
    var committedOffset: CGSize = .zero
    var isPinching = false

    var isZoomed: Bool { scale > 1.01 }
}

/// Una card a schermo intero: contenuto e info sovrapposte. I controlli del
/// video stanno sotto la card, nella pila.
struct SwipeCardView: View {
    let card: DeckCard
    let isTop: Bool
    let position: String
    let targetSize: CGSize
    let zoom: ZoomState
    /// Modello video condiviso dalla pila: solo la card in cima lo usa.
    let video: VideoPlaybackModel

    private var kind: AssetKind { AssetKind(card.asset) }

    var body: some View {
        AssetMediaView(asset: card.asset, isActive: isTop, targetSize: targetSize, video: video)
            .scaleEffect(zoom.scale)
            .offset(zoom.offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.06))
            .clipShape(.rect(cornerRadius: 32, style: .continuous))
            .overlay(alignment: .top) {
                if isTop, !zoom.isZoomed {
                    infoBar
                        .transition(.opacity)
                }
            }
            .contentShape(.rect(cornerRadius: 32, style: .continuous))
            .onTapGesture {
                if isTop, kind == .video {
                    video.toggleMute()
                }
            }
            .shadow(color: .black.opacity(isTop ? 0.25 : 0), radius: 16, y: 8)
    }

    private var infoBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                GlassChip {
                    Text(Formatters.dateTime(card.asset.creationDate))
                }
                GlassChip {
                    Label(typeDescription, systemImage: kind.systemImage)
                }
            }
            Spacer(minLength: 12)
            GlassChip {
                Text(position)
                    .monospacedDigit()
            }
        }
        .padding(12)
    }

    private var typeDescription: String {
        switch kind {
        case .video:
            "Video · \(Formatters.duration(card.asset.duration))"
        case .livePhoto:
            "Live Photo · tieni premuto"
        case .photo, .screenshot:
            kind.title
        }
    }
}
