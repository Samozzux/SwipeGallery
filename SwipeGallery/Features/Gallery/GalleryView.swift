import SwiftUI

/// Tab Galleria: tutta la libreria, con le Impostazioni nella toolbar.
struct GalleryView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @State private var model: AssetBrowserModel?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    AssetBrowserView(model: model, onOpenSettings: { showSettings = true })
                } else {
                    ProgressView()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if library.isLimited {
                    LimitedAccessBanner()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            if model == nil {
                model = AssetBrowserModel(scope: .library, library: library, store: store)
            }
        }
    }
}
