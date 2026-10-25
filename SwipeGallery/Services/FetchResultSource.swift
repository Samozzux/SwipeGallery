import Photos
import SwipeCore

/// Adatta un `PHFetchResult` alla coda di swipe: accesso per indice, senza
/// convertire tutta la libreria in un array.
struct FetchResultSource: IdentifierSource, Sendable {
    let fetchResult: PHFetchResult<PHAsset>

    var count: Int { fetchResult.count }

    func identifier(at index: Int) -> String {
        fetchResult.object(at: index).localIdentifier
    }

    func asset(at index: Int) -> PHAsset? {
        guard index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }
}
