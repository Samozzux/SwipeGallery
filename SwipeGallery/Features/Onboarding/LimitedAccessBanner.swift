import SwiftUI

/// Banner mostrato con accesso limitato: invita a dare l'accesso completo o a
/// modificare la selezione.
struct LimitedAccessBanner: View {
    @Environment(\.openURL) private var openURL
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accesso limitato")
                        .font(.subheadline.weight(.semibold))
                    Text("SwipeGallery vede solo le foto selezionate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Menu("Gestisci") {
                    Button("Modifica selezione", systemImage: "checklist") {
                        SystemActions.presentLimitedLibraryPicker()
                    }
                    Button("Consenti accesso completo", systemImage: "gear") {
                        if let url = SystemActions.settingsURL {
                            openURL(url)
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                Button("Chiudi", systemImage: "xmark") {
                    withAnimation { isDismissed = true }
                }
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }
}
