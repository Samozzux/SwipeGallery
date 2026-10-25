import Photos
import SwiftUI
import SwipeCore

/// Navigazione verso il dettaglio di un gruppo di foto simili.
struct SimilarGroupRoute: Hashable {
    let id: String
}

/// Elenco dei gruppi di foto doppie o simili, con l'analisi della libreria.
struct SimilarPhotosView: View {
    let model: SimilarPhotosModel

    @Environment(PhotoLibraryService.self) private var library
    @Environment(DecisionStore.self) private var store
    @AppStorage("similaritySensitivity") private var sensitivityRaw = SimilaritySensitivity.balanced.rawValue
    @AppStorage("similarShowReviewed") private var showReviewed = false

    private var sensitivity: SimilaritySensitivity {
        SimilaritySensitivity(rawValue: sensitivityRaw) ?? .balanced
    }

    private var visibleGroups: [SimilarGroup] {
        model.groups.filter { $0.isVisible(store.index, includeReviewed: showReviewed) }
    }

    var body: some View {
        Group {
            if model.phase == .idle, model.groups.isEmpty {
                introduction
            } else {
                groupList
            }
        }
        .navigationDestination(for: SimilarGroupRoute.self) { route in
            if let group = model.groups.first(where: { $0.id == route.id }) {
                SimilarGroupView(group: group)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                optionsMenu
            }
        }
        .onAppear {
            // Dopo la prima analisi le successive sono incrementali: si
            // aggiornano da sole quando la libreria è cambiata.
            if model.hasPreviousAnalysis, model.isStale(for: library) {
                model.analyze(library: library, sensitivity: sensitivity)
            }
        }
        .onChange(of: sensitivityRaw) {
            model.regroup(library: library, sensitivity: sensitivity)
        }
    }

    // MARK: - Contenuto

    private var introduction: some View {
        ContentUnavailableView {
            Label("Foto doppie e simili", systemImage: "square.on.square")
        } description: {
            Text("SwipeGallery confronta le tue foto sul telefono, senza rete, e raggruppa doppioni e scatti simili. La prima analisi può richiedere qualche minuto: tieni l'app aperta.")
        } actions: {
            Button("Avvia analisi") {
                model.analyze(library: library, sensitivity: sensitivity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private var groupList: some View {
        List {
            Section {
                statusRow
            }
            if model.phase == .ready, visibleGroups.isEmpty {
                Section {
                    Text(showReviewed || model.groups.isEmpty
                        ? "Nessuna foto doppia o simile con la sensibilità scelta."
                        : "Hai già valutato tutti i gruppi. Puoi mostrarli di nuovo dal menu in alto.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(visibleGroups) { group in
                NavigationLink(value: SimilarGroupRoute(id: group.id)) {
                    SimilarGroupRow(group: group, decisions: store.index)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch model.phase {
        case let .analyzing(done, total):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Analisi in corso…")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Annulla", role: .cancel) {
                        model.cancel()
                    }
                    .font(.subheadline)
                }
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text("\(Formatters.number(done)) di \(Formatters.number(total)) foto · lo schermo resta acceso")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
        case .grouping:
            HStack(spacing: 10) {
                ProgressView()
                Text("Raggruppamento…")
                    .foregroundStyle(.secondary)
            }
        case .ready, .idle:
            VStack(alignment: .leading, spacing: 2) {
                Text(visibleGroups.isEmpty ? "Nessun gruppo da valutare" : "\(Formatters.number(visibleGroups.count)) gruppi da valutare")
                    .font(.subheadline.weight(.semibold))
                Text("\(Formatters.number(model.analyzedCount)) foto analizzate · sensibilità: \(sensitivity.title.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optionsMenu: some View {
        Menu("Opzioni", systemImage: "slider.horizontal.3") {
            Picker("Sensibilità", selection: $sensitivityRaw) {
                ForEach(SimilaritySensitivity.allCases, id: \.self) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            Toggle("Mostra gruppi già valutati", isOn: $showReviewed)
            Divider()
            Button("Analizza di nuovo", systemImage: "arrow.clockwise") {
                model.analyze(library: library, sensitivity: sensitivity)
            }
            .disabled(model.isAnalyzing)
        }
    }
}

/// Riga di un gruppo: anteprime, data e conteggi.
struct SimilarGroupRow: View {
    let group: SimilarGroup
    let decisions: DecisionIndex

    private let thumbnailSide: CGFloat = 64

    var body: some View {
        let active = group.activeAssets(decisions)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(active.prefix(4), id: \.localIdentifier) { asset in
                    AssetThumbnail(asset: asset, side: thumbnailSide)
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                }
                if active.count > 4 {
                    Text("+\(active.count - 4)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: thumbnailSide, height: thumbnailSide)
                        .background(.quaternary, in: .rect(cornerRadius: 8, style: .continuous))
                }
            }
            HStack(spacing: 4) {
                Text("\(active.count) foto")
                    .fontWeight(.semibold)
                Text("·")
                Text(Formatters.dateTime(active.first?.creationDate))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
