import Photos
import SwiftUI
import SwipeCore

/// Video dal più pesante: scorri una riga per mandarlo nel cestino o tenerlo.
struct LargeVideosView: View {
    let model: LargeVideosModel

    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @State private var preview: VideoEntry?

    var body: some View {
        List {
            if model.hasLoaded, !model.entries.isEmpty {
                Section {
                    ForEach(model.entries) { entry in
                        row(for: entry)
                    }
                } header: {
                    Text("\(Formatters.number(model.entries.count)) video · \(Formatters.bytes(model.totalBytes)) in totale")
                } footer: {
                    Text("Scorri verso sinistra per mandare un video nel cestino, verso destra per tenerlo.")
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if !model.hasLoaded {
                ProgressView("Calcolo delle dimensioni…")
            } else if model.entries.isEmpty {
                ContentUnavailableView("Nessun video", systemImage: "film")
            }
        }
        .onAppear {
            model.reloadIfNeeded(library: library)
        }
        .onChange(of: library.changeCount) {
            model.reloadIfNeeded(library: library)
        }
        .fullScreenCover(item: $preview) { entry in
            previewView(for: entry)
        }
    }

    private func row(for entry: VideoEntry) -> some View {
        let id = entry.id
        let decision = store.decision(for: id)
        return Button {
            preview = entry
        } label: {
            HStack(spacing: 12) {
                AssetThumbnail(asset: entry.asset, side: 64)
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    .opacity(decision == .trashed ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.bytes.map(Formatters.bytes) ?? "Dimensione sconosciuta")
                        .font(.headline)
                        .monospacedDigit()
                    Text("\(Formatters.duration(entry.asset.duration)) · \(Formatters.dateTime(entry.asset.creationDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                switch decision {
                case .kept:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Tenuto")
                case .trashed:
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Nel cestino")
                case nil:
                    EmptyView()
                }
            }
            .font(.title3)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if decision == .trashed {
                Button("Ripristina", systemImage: "arrow.uturn.backward") {
                    store.restore([id])
                }
                .tint(.gray)
            } else {
                Button("Cestino", systemImage: "trash") {
                    store.setDecision(.trashed, for: id)
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading) {
            if decision != .kept {
                Button("Tieni", systemImage: "checkmark") {
                    store.setDecision(.kept, for: id)
                }
                .tint(.green)
            }
        }
    }

    private func previewView(for entry: VideoEntry) -> some View {
        let id = entry.id
        let isTrashed = store.decision(for: id) == .trashed
        return AssetPreviewView(
            asset: entry.asset,
            secondary: PreviewAction(title: "Tieni", systemImage: "checkmark") {
                store.setDecision(.kept, for: id)
                preview = nil
            },
            primary: isTrashed
                ? PreviewAction(title: "Ripristina", systemImage: "arrow.uturn.backward") {
                    store.restore([id])
                    preview = nil
                }
                : PreviewAction(title: "Cestino", systemImage: "trash", isDestructive: true) {
                    store.setDecision(.trashed, for: id)
                    preview = nil
                }
        )
    }
}
