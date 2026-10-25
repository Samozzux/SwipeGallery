import Photos
import SwiftUI

/// Tab Cestino: elementi scartati, ripristino e svuotamento.
struct TrashView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var model = TrashModel()
    @State private var preview: PreviewItem?
    @State private var pendingDeletion: PendingDeletion?
    @State private var outcome: DeletionOutcome?
    @State private var previewPendingDeletion: PendingDeletion?
    @State private var previewOutcome: DeletionOutcome?
    @State private var isDeleting = false
    @State private var showRestoreAllConfirmation = false
    @State private var width: CGFloat = 0

    private let spacing: CGFloat = 2

    private var side: CGFloat {
        max((width - spacing * 2) / 3, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !model.assets.isEmpty {
                    header
                    if side > 0 {
                        grid
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .overlay {
                if model.assets.isEmpty {
                    ContentUnavailableView(
                        "Il cestino è vuoto",
                        systemImage: "trash",
                        description: Text("Gli elementi che scarti con lo swipe compaiono qui. Nulla viene eliminato dalla libreria finché non svuoti il cestino.")
                    )
                }
            }
            .overlay {
                if isDeleting {
                    ProgressView("Eliminazione…")
                        .padding(20)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !model.assets.isEmpty {
                    actionBar
                }
            }
            .navigationTitle("Cestino")
            .toolbar {
                if !model.assets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(model.isSelecting ? "Fine" : "Seleziona") {
                            withAnimation { model.isSelecting.toggle() }
                        }
                    }
                }
            }
            .onAppear {
                model.reload(library: library, store: store)
            }
            .onChange(of: store.revision) {
                if router.selectedTab == .trash {
                    model.reload(library: library, store: store)
                }
            }
            .onChange(of: router.selectedTab) { _, tab in
                if tab == .trash {
                    model.reload(library: library, store: store)
                }
            }
            .onChange(of: library.changeCount) {
                model.reload(library: library, store: store, force: true)
            }
            .fullScreenCover(item: $preview) { item in
                AssetPreviewView(
                    asset: item.asset,
                    secondary: PreviewAction(title: "Ripristina", systemImage: "arrow.uturn.backward") {
                        store.restore([item.id])
                        preview = nil
                    },
                    primary: PreviewAction(title: "Elimina definitivamente", systemImage: "trash", isDestructive: true) {
                        previewPendingDeletion = PendingDeletion(ids: [item.id])
                    }
                )
                .disabled(isDeleting)
                .deletionAlerts(
                    pending: $previewPendingDeletion,
                    outcome: $previewOutcome,
                    perform: { ids in previewOutcome = await delete(ids) },
                    onSuccessAcknowledged: { preview = nil },
                    openPhotos: openPhotosApp
                )
            }
            .deletionAlerts(
                pending: $pendingDeletion,
                outcome: $outcome,
                perform: { ids in outcome = await delete(ids) },
                onSuccessAcknowledged: {},
                openPhotos: openPhotosApp
            )
            .confirmationDialog(
                "Ripristinare \(Formatters.items(model.assets.count))?",
                isPresented: $showRestoreAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Ripristina tutto") {
                    store.restore(model.allIDs)
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Torneranno tra gli elementi da valutare.")
            }
        }
    }

    // MARK: - Contenuto

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(Formatters.items(model.assets.count))
                    .font(.headline)
                if let bytes = model.estimatedBytes, bytes > 0 {
                    Text("· circa \(Formatters.bytes(bytes))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Nulla viene eliminato dalla libreria finché non svuoti il cestino.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: 3), spacing: spacing) {
            ForEach(model.assets, id: \.localIdentifier) { asset in
                cell(for: asset)
            }
        }
        .padding(.bottom, 16)
    }

    private func cell(for asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isSelected = model.selection.contains(id)
        return Button {
            if model.isSelecting {
                if isSelected {
                    model.selection.remove(id)
                } else {
                    model.selection.insert(id)
                }
            } else {
                preview = PreviewItem(asset: asset)
            }
        } label: {
            AssetThumbnail(asset: asset, side: side)
                .overlay {
                    ThumbnailBadges(asset: asset, decision: nil)
                }
                .overlay(alignment: .bottomLeading) {
                    if model.isSelecting {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, isSelected ? Color.accentColor : Color.black.opacity(0.25))
                            .padding(6)
                    }
                }
                .opacity(model.isSelecting && !isSelected ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if model.isSelecting {
                    let selected = Array(model.selection)
                    Button("Ripristina (\(selected.count))", systemImage: "arrow.uturn.backward") {
                        store.restore(selected)
                        model.isSelecting = false
                    }
                    .buttonStyle(.glass)
                    .disabled(selected.isEmpty)

                    Button("Elimina (\(selected.count))", systemImage: "trash", role: .destructive) {
                        pendingDeletion = PendingDeletion(ids: orderedSelection())
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(selected.isEmpty)
                } else {
                    Button("Ripristina tutto", systemImage: "arrow.uturn.backward") {
                        showRestoreAllConfirmation = true
                    }
                    .buttonStyle(.glass)

                    Button("Svuota cestino", systemImage: "trash", role: .destructive) {
                        pendingDeletion = PendingDeletion(ids: model.allIDs)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                }
            }
            .font(.body.weight(.semibold))
            .controlSize(.large)
        }
        .disabled(isDeleting)
        .padding(.bottom, 8)
    }

    private func openPhotosApp() {
        if let url = SystemActions.photosAppURL {
            openURL(url)
        }
    }

    private func orderedSelection() -> [String] {
        model.allIDs.filter { model.selection.contains($0) }
    }

    // MARK: - Eliminazione

    /// Elimina dalla libreria con un'unica richiesta. Se l'utente annulla dalla
    /// conferma di sistema o c'è un errore, il cestino resta invariato.
    private func delete(_ ids: [String]) async -> DeletionOutcome {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await library.deleteAssets(withIDs: ids)
            store.forget(ids)
            model.isSelecting = false
            return .success(count: ids.count)
        } catch {
            return .failure(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let photosError = error as? PHPhotosError, photosError.code == .userCancelled {
            return "Hai annullato l'eliminazione: il cestino non è stato modificato."
        }
        return "Il cestino non è stato modificato. (\(error.localizedDescription))"
    }
}

// MARK: - Supporto

private struct PreviewItem: Identifiable {
    let asset: PHAsset
    var id: String { asset.localIdentifier }
}

struct PendingDeletion: Identifiable {
    let ids: [String]
    var id: [String] { ids }
}

enum DeletionOutcome: Identifiable {
    case success(count: Int)
    case failure(String)

    var id: String {
        switch self {
        case let .success(count): "success-\(count)"
        case let .failure(message): "failure-\(message)"
        }
    }
}

private extension View {
    /// Conferma dell'app prima della conferma di sistema, e messaggio finale.
    func deletionAlerts(
        pending: Binding<PendingDeletion?>,
        outcome: Binding<DeletionOutcome?>,
        perform: @escaping @MainActor ([String]) async -> Void,
        onSuccessAcknowledged: @escaping @MainActor () -> Void,
        openPhotos: @escaping @MainActor () -> Void
    ) -> some View {
        alert(
            pending.wrappedValue.map { $0.ids.count == 1 ? "Eliminare 1 elemento dalla libreria?" : "Eliminare \(Formatters.number($0.ids.count)) elementi dalla libreria?" } ?? "",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            presenting: pending.wrappedValue
        ) { deletion in
            Button("Elimina", role: .destructive) {
                Task { await perform(deletion.ids) }
            }
            Button("Annulla", role: .cancel) {}
        } message: { _ in
            Text("iOS chiederà un'ulteriore conferma.")
        }
        .alert(
            outcomeTitle(outcome.wrappedValue),
            isPresented: Binding(
                get: { outcome.wrappedValue != nil },
                set: { if !$0 { outcome.wrappedValue = nil } }
            ),
            presenting: outcome.wrappedValue
        ) { result in
            if case .success = result {
                Button("Apri Foto") {
                    onSuccessAcknowledged()
                    openPhotos()
                }
            }
            Button("OK", role: .cancel) {
                if case .success = result {
                    onSuccessAcknowledged()
                }
            }
        } message: { result in
            switch result {
            case .success:
                Text("Gli elementi sono in Eliminati di recente nell'app Foto per 30 giorni. Per liberare spazio subito: Foto → Album → Eliminati di recente → Seleziona → Elimina tutto.")
            case let .failure(message):
                Text(message)
            }
        }
    }

    private func outcomeTitle(_ outcome: DeletionOutcome?) -> String {
        switch outcome {
        case let .success(count): count == 1 ? "Elemento eliminato" : "\(Formatters.number(count)) elementi eliminati"
        case .failure: "Eliminazione non riuscita"
        case nil: ""
        }
    }
}
