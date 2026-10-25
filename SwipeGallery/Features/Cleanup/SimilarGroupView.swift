import Photos
import SwiftUI
import SwipeCore

/// Dettaglio di un gruppo: si sceglie cosa tenere, il resto va nel cestino
/// dell'app (nulla viene eliminato finché non si svuota il cestino).
struct SimilarGroupView: View {
    let group: SimilarGroup

    @Environment(DecisionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Foto da mandare nel cestino.
    @State private var selection: Set<String>
    @State private var showComparison = false
    @State private var width: CGFloat = 0

    private let spacing: CGFloat = 6

    init(group: SimilarGroup) {
        self.group = group
        let ids = Set(group.assets.map(\.localIdentifier))
        _selection = State(initialValue: ids.subtracting([group.suggestedKeepID].compactMap { $0 }))
    }

    private var active: [PHAsset] {
        group.activeAssets(store.index)
    }

    private var selectedActive: [String] {
        active.map(\.localIdentifier).filter { selection.contains($0) }
    }

    private var side: CGFloat {
        max((width - 32 - spacing) / 2, 0)
    }

    var body: some View {
        ScrollView {
            Text("Tocca le foto per scegliere quali tenere. Quelle segnate con il cestino finiranno nel cestino dell'app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            if side > 0 {
                LazyVGrid(columns: [GridItem(.fixed(side), spacing: spacing), GridItem(.fixed(side), spacing: spacing)], spacing: spacing) {
                    ForEach(active, id: \.localIdentifier) { asset in
                        tile(for: asset)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
        .navigationTitle("\(active.count) foto simili")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Confronta", systemImage: "rectangle.on.rectangle") {
                    showComparison = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .fullScreenCover(isPresented: $showComparison) {
            SimilarComparisonView(assets: active, suggestedKeepID: group.suggestedKeepID, selection: $selection)
        }
    }

    private func tile(for asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isTrashed = selection.contains(id)
        return Button {
            if isTrashed {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
        } label: {
            AssetThumbnail(asset: asset, side: side)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .opacity(isTrashed ? 0.55 : 1)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isTrashed ? "trash.circle.fill" : "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isTrashed ? Color.red : Color.green)
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        if id == group.suggestedKeepID {
                            GlassChip { Label("Consigliata", systemImage: "star.fill") }
                        }
                        GlassChip { Text(details(for: asset)) }
                    }
                    .padding(8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTrashed ? "Da mandare nel cestino" : "Da tenere")
    }

    private func details(for asset: PHAsset) -> String {
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000
        let time = asset.creationDate?.formatted(Date.FormatStyle(time: .standard).locale(Formatters.locale)) ?? ""
        return "\(megapixels.formatted(.number.precision(.fractionLength(1)).locale(Formatters.locale))) MP · \(time)"
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button("Tieni tutte", systemImage: "checkmark") {
                    apply(trashing: [])
                }
                .buttonStyle(.glass)

                Button("Nel cestino (\(selectedActive.count))", systemImage: "trash", role: .destructive) {
                    apply(trashing: Set(selectedActive))
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(selectedActive.isEmpty)
            }
            .font(.body.weight(.semibold))
            .controlSize(.large)
        }
        .padding(.bottom, 8)
    }

    /// Le foto scelte vanno nel cestino, le altre risultano tenute: il gruppo
    /// è valutato e sparisce dall'elenco.
    private func apply(trashing ids: Set<String>) {
        for asset in active {
            let id = asset.localIdentifier
            if ids.contains(id) {
                store.setDecision(.trashed, for: id)
            } else if store.decision(for: id) == nil {
                store.setDecision(.kept, for: id)
            }
        }
        dismiss()
    }
}

/// Confronto a schermo intero delle foto di un gruppo, scorrendo fra le
/// pagine.
struct SimilarComparisonView: View {
    let assets: [PHAsset]
    let suggestedKeepID: String?
    @Binding var selection: Set<String>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var currentID: String?
    @State private var size: CGSize = .zero
    @State private var video = VideoPlaybackModel()

    private var currentIndex: Int {
        assets.firstIndex { $0.localIdentifier == currentID } ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentID) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    AssetMediaView(
                        asset: asset,
                        isActive: asset.localIdentifier == currentID,
                        targetSize: CGSize(width: size.width * displayScale, height: size.height * displayScale),
                        video: video
                    )
                    .tag(Optional(asset.localIdentifier))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                size = newSize
            }
        }
        .overlay(alignment: .top) {
            HStack {
                GlassCircleButton(title: "Chiudi", systemImage: "xmark", size: 44) {
                    dismiss()
                }
                Spacer()
                if currentID == suggestedKeepID {
                    GlassChip { Label("Consigliata", systemImage: "star.fill") }
                }
                GlassChip {
                    Text("\(currentIndex + 1) / \(assets.count)")
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if let currentID {
                let isTrashed = selection.contains(currentID)
                Button(
                    isTrashed ? "Nel cestino" : "Da tenere",
                    systemImage: isTrashed ? "trash" : "checkmark"
                ) {
                    if isTrashed {
                        selection.remove(currentID)
                    } else {
                        selection.insert(currentID)
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(isTrashed ? .red : .green)
                .controlSize(.large)
                .font(.body.weight(.semibold))
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            if currentID == nil {
                currentID = assets.first?.localIdentifier
            }
        }
        .preferredColorScheme(.dark)
    }
}
