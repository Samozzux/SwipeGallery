import Foundation
import Photos
import SwipeCore

/// Tipo di elemento mostrato nelle info sovrapposte.
enum AssetKind {
    case photo
    case video
    case livePhoto
    case screenshot

    init(_ asset: PHAsset) {
        if asset.mediaType == .video {
            self = .video
        } else if asset.mediaSubtypes.contains(.photoScreenshot) {
            self = .screenshot
        } else if asset.mediaSubtypes.contains(.photoLive) {
            self = .livePhoto
        } else {
            self = .photo
        }
    }

    var title: String {
        switch self {
        case .photo: "Foto"
        case .video: "Video"
        case .livePhoto: "Live Photo"
        case .screenshot: "Screenshot"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        case .livePhoto: "livephoto"
        case .screenshot: "camera.viewfinder"
        }
    }

    var supportsZoom: Bool {
        self != .video
    }
}

/// Formattatori in italiano, indipendenti dalla lingua del dispositivo.
enum Formatters {
    static let locale = Locale(identifier: "it_IT")

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "Data sconosciuta" }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    static func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file).locale(locale))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        DurationFormatting.string(fromSeconds: seconds)
    }

    /// "1 elemento" / "3 elementi".
    static func items(_ count: Int) -> String {
        count == 1 ? "1 elemento" : "\(number(count)) elementi"
    }
}
