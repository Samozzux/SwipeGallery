import Photos
import SwiftUI

/// Anteprima a schermo intero di un elemento nel cestino.
struct TrashPreviewView: View {
    let asset: PHAsset
    let onRestore: () -> Void
    let onDelete: () -> Void

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
                    GlassChip { Label(kind.title, systemImage: kind.systemImage) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Ripristina", systemImage: "arrow.uturn.backward", action: onRestore)
                        .buttonStyle(.glass)
                    Button("Elimina definitivamente", systemImage: "trash", role: .destructive, action: onDelete)
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                }
                .font(.body.weight(.semibold))
                .controlSize(.large)
            }
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }
}
