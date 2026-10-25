import SwiftUI

/// Strumenti del tab Pulizia.
enum CleanupTool: String, GlassSegment {
    case similar
    case videos

    var id: Self { self }

    var title: String {
        switch self {
        case .similar: "Simili"
        case .videos: "Video pesanti"
        }
    }

    var systemImage: String {
        switch self {
        case .similar: "square.on.square"
        case .videos: "film.stack"
        }
    }
}

/// Tab Pulizia: foto doppie o simili e video più pesanti. Le scelte finiscono
/// nello stesso cestino dell'app degli swipe.
struct CleanupView: View {
    @State private var tool: CleanupTool = .similar
    @State private var similar = SimilarPhotosModel()
    @State private var videos = LargeVideosModel()

    var body: some View {
        NavigationStack {
            Group {
                switch tool {
                case .similar:
                    SimilarPhotosView(model: similar)
                case .videos:
                    LargeVideosView(model: videos)
                }
            }
            .navigationTitle("Pulizia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    GlassSegmentedControl(selection: $tool)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }
}
