import SwiftUI

/// Vista comune a Galleria e Album: swipe predefinito, selettore
/// Swipe / Griglia e controlli della coda manuale.
struct AssetBrowserView: View {
    @Bindable var model: AssetBrowserModel
    var albumTitle: String?
    var onOpenSettings: (() -> Void)?

    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var isInAlbum: Bool { albumTitle != nil }

    var body: some View {
        content
            .navigationTitle(albumTitle ?? "Galleria")
            .navigationBarTitleDisplayMode(.inline)
            // In swipe il gesto "indietro" di sistema entrerebbe in conflitto con
            // lo swipe verso destra: lo si sostituisce con un pulsante.
            .navigationBarBackButtonHidden(isInAlbum && model.mode == .swipe)
            .toolbar { toolbarContent }
            .onAppear {
                model.libraryDidChange()
                model.decisionsDidChange()
            }
            .onChange(of: library.changeCount) {
                model.libraryDidChange()
            }
            .onChange(of: store.revision) {
                model.decisionsDidChange()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.mode {
        case .swipe:
            SwipeDeckView(
                deck: model.activeDeck,
                albumTitle: albumTitle,
                onExitManual: { model.exitManual() }
            )
            .id(ObjectIdentifier(model.activeDeck))
        case .grid:
            AssetGridView(model: model)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            GlassSegmentedControl(selection: $model.mode)
        }
        .sharedBackgroundVisibility(.hidden)

        if isInAlbum, model.mode == .swipe {
            ToolbarItem(placement: .topBarLeading) {
                Button("Album", systemImage: "chevron.backward") {
                    dismiss()
                }
            }
        }

        if model.mode == .swipe, let manualDeck = model.manualDeck {
            ToolbarItem(placement: .topBarLeading) {
                Button("Inverti direzione", systemImage: "arrow.up.arrow.down") {
                    manualDeck.reverseDirection()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Torna agli elementi da valutare", systemImage: "xmark") {
                    model.exitManual()
                }
            }
        }

        if let onOpenSettings {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Impostazioni", systemImage: "gearshape", action: onOpenSettings)
            }
        }
    }
}
