import SwiftUI

/// Schermata di benvenuto al primo avvio, con la richiesta di accesso.
struct OnboardingView: View {
    @Environment(PhotoLibraryService.self) private var library
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 120, height: 120)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.15)), in: .circle)

            VStack(spacing: 10) {
                Text("Benvenuto in SwipeGallery")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Ripulisci la galleria un elemento alla volta.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                feature("hand.draw", "Swipe a sinistra per il cestino, a destra per tenere. Puoi invertire i lati nelle Impostazioni.")
                feature("trash", "Nulla viene eliminato finché non svuoti il cestino dell'app.")
                feature("lock", "Le foto restano sul tuo iPhone: l'app non usa la rete.")
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                isRequesting = true
                Task {
                    await library.requestAuthorization()
                    isRequesting = false
                }
            } label: {
                Text("Consenti accesso")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(isRequesting)
        }
        .padding(24)
    }

    private func feature(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Mostrata quando l'accesso alla libreria è negato.
struct AccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Accesso alle foto negato", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("SwipeGallery ha bisogno dell'accesso alla Libreria Foto per mostrarti foto e video. Puoi concederlo dalle Impostazioni di iOS.")
        } actions: {
            Button("Apri Impostazioni") {
                if let url = SystemActions.settingsURL {
                    openURL(url)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }
}
