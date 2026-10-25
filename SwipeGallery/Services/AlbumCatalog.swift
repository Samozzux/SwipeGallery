import Foundation
import Photos
import SwipeCore

/// Riepilogo di un album per il tab Album.
struct AlbumSummary: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case user
        case smart
    }

    let collection: PHAssetCollection
    let title: String
    let kind: Kind
    let totalCount: Int
    let unratedCount: Int
    /// Elemento più recente, usato come copertina.
    let cover: PHAsset?

    var id: String { collection.localIdentifier }

    static func == (lhs: AlbumSummary, rhs: AlbumSummary) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.totalCount == rhs.totalCount
            && lhs.unratedCount == rhs.unratedCount
            && lhs.cover?.localIdentifier == rhs.cover?.localIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Elenco degli album da mostrare: album dell'utente (anche dentro cartelle) e
/// smart album utili. Restano fuori album vuoti, album condivisi iCloud,
/// "Recenti" e "Nascosti".
enum AlbumCatalog {
    private static let smartAlbums: [(subtype: PHAssetCollectionSubtype, title: String)] = [
        (.smartAlbumFavorites, "Preferiti"),
        (.smartAlbumVideos, "Video"),
        (.smartAlbumSelfPortraits, "Selfie"),
        (.smartAlbumLivePhotos, "Live Photo"),
        (.smartAlbumDepthEffect, "Ritratti"),
        (.smartAlbumScreenshots, "Screenshot"),
        (.smartAlbumScreenRecordings, "Registrazioni schermo"),
        (.smartAlbumPanoramas, "Panoramiche"),
        (.smartAlbumBursts, "Raffiche"),
    ]

    /// Costruisce i riepiloghi. Scorre gli identificatori di ogni album, quindi
    /// va eseguito fuori dal main thread.
    static func loadSummaries(includeVideos: Bool, decisions: DecisionIndex) -> [AlbumSummary] {
        var summaries: [AlbumSummary] = []
        for album in userAlbums() {
            let title = album.localizedTitle ?? "Senza nome"
            if let summary = summary(for: album, title: title, kind: .user, includeVideos: includeVideos, decisions: decisions) {
                summaries.append(summary)
            }
        }
        for entry in smartAlbums {
            let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: entry.subtype, options: nil)
            guard let album = result.firstObject else { continue }
            if let summary = summary(for: album, title: entry.title, kind: .smart, includeVideos: includeVideos, decisions: decisions) {
                summaries.append(summary)
            }
        }
        return summaries
    }

    private static func summary(
        for album: PHAssetCollection,
        title: String,
        kind: AlbumSummary.Kind,
        includeVideos: Bool,
        decisions: DecisionIndex
    ) -> AlbumSummary? {
        let assets = PHAsset.fetchAssets(in: album, options: PhotoLibraryService.assetOptions(includeVideos: includeVideos))
        guard assets.count > 0 else { return nil }
        var unrated = 0
        for index in 0 ..< assets.count where !decisions.isDecided(assets.object(at: index).localIdentifier) {
            unrated += 1
        }
        return AlbumSummary(
            collection: album,
            title: title,
            kind: kind,
            totalCount: assets.count,
            unratedCount: unrated,
            cover: assets.firstObject
        )
    }

    /// Album creati dall'utente, comprese le cartelle annidate.
    private static func userAlbums() -> [PHAssetCollection] {
        var albums: [PHAssetCollection] = []
        collectAlbums(from: PHCollectionList.fetchTopLevelUserCollections(with: nil), into: &albums)
        return albums
    }

    private static func collectAlbums(from collections: PHFetchResult<PHCollection>, into albums: inout [PHAssetCollection]) {
        for index in 0 ..< collections.count {
            let collection = collections.object(at: index)
            if let album = collection as? PHAssetCollection {
                if album.assetCollectionType == .album, album.assetCollectionSubtype == .albumRegular {
                    albums.append(album)
                }
            } else if let folder = collection as? PHCollectionList {
                collectAlbums(from: PHCollection.fetchCollections(in: folder, options: nil), into: &albums)
            }
        }
    }
}
