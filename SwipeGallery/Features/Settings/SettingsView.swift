import Photos
import SwiftUI
import SwipeCore

/// Impostazioni, aperte come sheet dal tab Galleria.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store

    @AppStorage(AppSettings.trashEdgeKey) private var trashEdgeRaw = AppSettings.defaultTrashEdge.rawValue
    @AppStorage(AppSettings.includeVideosKey) private var includeVideos = true
    @AppStorage(AppSettings.hapticsEnabledKey) private var hapticsEnabled = true
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Lato per il cestino", selection: $trashEdgeRaw) {
                        Text("Sinistra").tag(SwipeEdge.left.rawValue)
                        Text("Destra").tag(SwipeEdge.right.rawValue)
                    }
                    Toggle("Includi video", isOn: $includeVideos)
                    Toggle("Feedback aptico", isOn: $hapticsEnabled)
                } header: {
                    Text("Swipe")
                } footer: {
                    Text(swipeFooter)
                }

                Section {
                    LabeledContent("Permesso", value: authorizationDescription)
                    if library.isLimited {
                        Button("Gestisci selezione") {
                            SystemActions.presentLimitedLibraryPicker()
                        }
                    }
                    if library.authorization != .authorized {
                        Button("Apri Impostazioni di iOS") {
                            if let url = SystemActions.settingsURL {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Libreria Foto")
                }

                Section {
                    Button("Azzera progresso", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .disabled(store.index.keptCount == 0)
                } header: {
                    Text("Progresso")
                } footer: {
                    Text("\(Formatters.items(store.index.keptCount)) tenuti. Azzerare il progresso li riporta tra quelli da valutare; il cestino non viene toccato.")
                }

                Section {
                    LabeledContent("Versione", value: Self.appVersion)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Azzerare il progresso?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Azzera progresso", role: .destructive) {
                    store.resetKept()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Gli elementi tenuti torneranno da valutare. Il cestino non viene modificato.")
            }
        }
    }

    private var swipeFooter: String {
        let edge = SwipeEdge(rawValue: trashEdgeRaw) ?? AppSettings.defaultTrashEdge
        return edge == .left
            ? "Swipe a sinistra per il cestino, a destra per tenere."
            : "Swipe a destra per il cestino, a sinistra per tenere."
    }

    private var authorizationDescription: String {
        switch library.authorization {
        case .authorized: "Accesso completo"
        case .limited: "Accesso limitato"
        case .denied: "Negato"
        case .restricted: "Limitato dal dispositivo"
        case .notDetermined: "Non richiesto"
        @unknown default: "Sconosciuto"
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
