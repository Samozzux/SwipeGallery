import Photos
import SwiftUI

/// Azione mostrata nella barra in basso dell'anteprima.
struct PreviewAction {
    let title: String
    let systemImage: String
    var isDestructive = false
    let perform: () -> Void
}

/// Anteprima a schermo intero di un elemento, con due azioni (per esempio
/// Ripristina / Elimina nel cestino, Tieni / Cestino per i video).
struct AssetPreviewView: View {
    let asset: PHAsset
    let secondary: PreviewAction
    let primary: PreviewAction

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var video = VideoPlaybackModel()
    @State private var size: CGSize = .zero

    private var kind: AssetKind { AssetKind(asset) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AssetMediaView(
                asset: asset,
                isActive: true,
                targetSize: CGSize(width: size.width * displayScale, height: size.height * displayScale),
                video: video
            )
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                size = newSize
            }
            .contentShape(.rect)
            .onTapGesture {
                if kind == .video {
                    video.toggleMute()
                }
            }
        }
        .overlay(alignment: .top) {
            HStack(alignment: .top) {
                GlassCircleButton(title: "Chiudi", systemImage: "xmark", size: 44) {
                    dismiss()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    GlassChip { Text(Formatters.dateTime(asset.creationDate)) }
                    GlassChip { Label(kindDescription, systemImage: kind.systemImage) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                if kind == .video {
                    VideoControlBar(video: video)
                        .padding(.horizontal, 16)
                }
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        button(for: secondary)
                            .buttonStyle(.glass)
                        button(for: primary)
                            .buttonStyle(.glassProminent)
                            .tint(primary.isDestructive ? .red : .accentColor)
                    }
                    .font(.body.weight(.semibold))
                    .controlSize(.large)
                }
            }
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func button(for action: PreviewAction) -> some View {
        Button(
            action.title,
            systemImage: action.systemImage,
            role: action.isDestructive ? .destructive : nil,
            action: action.perform
        )
    }

    private var kindDescription: String {
        kind == .video ? "Video · \(Formatters.duration(asset.duration))" : kind.title
    }
}
