import Observation

enum AppTab: Hashable {
    case gallery
    case albums
    case cleanup
    case trash
}

/// Stato di navigazione condiviso, per esempio per passare al cestino dallo
/// stato vuoto dello swipe.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .gallery
}
