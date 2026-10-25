import Foundation
import SwipeCore

/// Chiavi e valori predefiniti delle impostazioni salvate in `@AppStorage`.
enum AppSettings {
    static let trashEdgeKey = "trashEdge"
    static let includeVideosKey = "includeVideos"
    static let hapticsEnabledKey = "hapticsEnabled"
    static let albumTrashWarningShownKey = "albumTrashWarningShown"

    static let defaultTrashEdge = SwipeEdge.left

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            trashEdgeKey: defaultTrashEdge.rawValue,
            includeVideosKey: true,
            hapticsEnabledKey: true,
            albumTrashWarningShownKey: false,
        ])
    }

    static var includeVideos: Bool {
        UserDefaults.standard.bool(forKey: includeVideosKey)
    }
}
