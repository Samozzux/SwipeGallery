import Photos
import SwiftUI
import SwipeCore

/// Griglia a 3 colonne di tutti gli elementi, dal più recente. Toccando una
/// miniatura si sceglie da dove e in che direzione far partire lo swipe.
struct AssetGridView: View {
    let model: AssetBrowserModel

    @Environment(DecisionStore.self) private var store
    @State private var width: CGFloat = 0

    private let spacing: CGFloat = 2
    private let columnCount = 3

    private var side: CGFloat {
        max((width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 0)
    }

    var body: some View {
        ScrollView {
            header
            if side > 0 {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: columnCount),
                    spacing: spacing
                ) {
                    ForEach(0 ..< model.fetchResult.count, id: \.self) { index in
                        cell(at: index)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
        .overlay {
            if model.fetchResult.count == 0 {
                ContentUnavailableView("Nessun elemento", systemImage: "photo.on.rectangle.angled")
            }
        }
    }

    private var header: some View {
        HStack {
            Text(Formatters.items(model.fetchResult.count))
            if let remaining = model.defaultDeck.remainingCount {
                Text("·")
                Text("\(Formatters.number(remaining)) da valutare")
            }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func cell(at index: Int) -> some View {
        let asset = model.fetchResult.object(at: index)
        let decision = store.decision(for: asset.localIdentifier)
        Menu {
            if decision == .trashed {
                Button("Ripristina", systemImage: "arrow.uturn.backward") {
                    store.restore([asset.localIdentifier])
                }
            } else {
                Button("Vai verso le più recenti", systemImage: "arrow.up") {
                    model.startManual(at: index, direction: .towardNewer)
                }
                Button("Vai verso le più vecchie", systemImage: "arrow.down") {
                    model.startManual(at: index, direction: .towardOlder)
                }
            }
        } label: {
            AssetThumbnail(asset: asset, side: side)
                .opacity(decision == .trashed ? 0.45 : 1)
                .overlay {
                    ThumbnailBadges(asset: asset, decision: decision)
                }
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .accessibilityLabel(accessibilityLabel(for: asset, decision: decision))
    }

    private func accessibilityLabel(for asset: PHAsset, decision: Decision?) -> String {
        var parts = [AssetKind(asset).title, Formatters.dateTime(asset.creationDate)]
        switch decision {
        case .kept: parts.append("tenuto")
        case .trashed: parts.append("nel cestino")
        case nil: break
        }
        return parts.joined(separator: ", ")
    }
}
