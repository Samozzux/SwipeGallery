import SwiftUI

/// Barra dei tab di sistema: in iOS 26 è piccola, fluttuante e in Liquid Glass.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(DecisionStore.self) private var store

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Galleria", systemImage: "photo.stack", value: AppTab.gallery) {
                GalleryView()
            }
            Tab("Album", systemImage: "rectangle.stack", value: AppTab.albums) {
                AlbumsView()
            }
            Tab("Pulizia", systemImage: "sparkles", value: AppTab.cleanup) {
                CleanupView()
            }
            Tab("Cestino", systemImage: "trash", value: AppTab.trash) {
                TrashView()
            }
            .badge(store.index.trashedCount)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
