import SwiftData
import SwiftUI

@main
struct SwipeGalleryApp: App {
    private let container: ModelContainer
    @State private var store: DecisionStore
    @State private var library: PhotoLibraryService
    @State private var router = AppRouter()

    init() {
        AppSettings.registerDefaults()
        let container = Self.makeContainer()
        let store = DecisionStore(context: container.mainContext)
        let library = PhotoLibraryService(includeVideos: AppSettings.includeVideos)
        library.onAssetsRemoved = { [weak store] ids in
            store?.forget(ids)
        }
        self.container = container
        _store = State(initialValue: store)
        _library = State(initialValue: library)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(library)
                .environment(router)
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: AssetDecision.self)
        } catch {
            // Se il database su disco non si apre, l'app resta usabile senza
            // persistenza invece di chiudersi.
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: AssetDecision.self, configurations: configuration)
            } catch {
                fatalError("Impossibile creare il database delle decisioni: \(error)")
            }
        }
    }
}
