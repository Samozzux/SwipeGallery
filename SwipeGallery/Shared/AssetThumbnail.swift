import Photos
import SwiftUI
import SwipeCore
import UIKit

/// Miniatura quadrata di un asset, caricata quando entra nello schermo.
struct AssetThumbnail: View {
    let asset: PHAsset
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .task(id: asset.localIdentifier) {
                let pixels = (side * displayScale).rounded()
                guard pixels > 0 else { return }
                image = await ImageLoader.shared.thumbnail(for: asset, targetSize: CGSize(width: pixels, height: pixels))
            }
    }
}

/// Badge di stato sulle miniature: spunta per i tenuti, cestino per gli
/// scartati, durata per i video.
struct ThumbnailBadges: View {
    let asset: PHAsset
    let decision: Decision?

    var body: some View {
        ZStack {
            if decision == .trashed {
                Color.black.opacity(0.35)
            }
            VStack {
                HStack {
                    Spacer()
                    switch decision {
                    case .kept:
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                    case .trashed:
                        Image(systemName: "trash.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    case nil:
                        EmptyView()
                    }
                }
                Spacer()
                if asset.mediaType == .video {
                    HStack {
                        Spacer()
                        Text(Formatters.duration(asset.duration))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
            }
            .font(.title3)
            .padding(5)
        }
        .allowsHitTesting(false)
    }
}
