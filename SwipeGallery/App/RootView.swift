import SwiftUI

/// Sceglie fra benvenuto, accesso negato e app vera e propria in base al
/// permesso sulla libreria.
struct RootView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.includeVideosKey) private var includeVideos = true
    @State private var didPrune = false

    var body: some View {
        Group {
            switch library.authorization {
            case .authorized, .limited:
                RootTabView()
            case .notDetermined:
                OnboardingView()
            default:
                AccessDeniedView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                library.refreshAuthorization()
            }
        }
        .onChange(of: includeVideos, initial: true) { _, newValue in
            library.includeVideos = newValue
        }
        .task(id: library.authorization) {
            guard library.authorization == .authorized, !didPrune else { return }
            didPrune = true
            library.pruneMissingAssets(knownIDs: store.index.allIDs)
        }
    }
}
