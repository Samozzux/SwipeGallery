import Foundation
import Photos

/// Dimensione su disco di un asset, sommando `fileSize` delle sue risorse
/// (foto, video, parte video delle Live Photo). Non è un'API pubblica
/// documentata: se non è disponibile si restituisce `nil`. Le chiamate sono
/// sincrone, quindi va usato fuori dal main thread.
enum AssetFileSize {
    private static let key = "fileSize"

    static func bytes(of asset: PHAsset) -> Int64? {
        var total: Int64 = 0
        var foundAny = false
        for resource in PHAssetResource.assetResources(for: asset) {
            guard resource.responds(to: NSSelectorFromString(key)),
                  let size = (resource.value(forKey: key) as? NSNumber)?.int64Value
            else { continue }
            total += size
            foundAny = true
        }
        return foundAny ? total : nil
    }
}
