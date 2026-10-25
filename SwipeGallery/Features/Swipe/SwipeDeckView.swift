import SwiftUI
import SwipeCore

/// Pila di card con gesto di swipe, pulsanti di supporto, annulla e stato vuoto.
struct SwipeDeckView: View {
    let deck: SwipeDeckModel
    /// Nome dell'album, se la pila è dentro un album.
    var albumTitle: String?
    var onExitManual: (() -> Void)?

    @Environment(AppRouter.self) private var router
    @Environment(\.displayScale) private var displayScale
    @AppStorage(AppSettings.trashEdgeKey) private var trashEdgeRaw = AppSettings.defaultTrashEdge.rawValue
    @AppStorage(AppSettings.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.albumTrashWarningShownKey) private var albumWarningShown = false

    @State private var dragOffset: CGFloat = 0
    @State private var zoom = ZoomState()
    @State private var isAnimatingOut = false
    @State private var cardSize: CGSize = .zero
    /// Lato da cui rientra la card quando si annulla.
    @State private var insertionEdge: SwipeEdge = .left
    @State private var feedback = FeedbackEvent.none
    @State private var showAlbumWarning = false

    private let threshold = SwipeThreshold()

    private var layout: SwipeLayout {
        SwipeLayout(trashEdge: SwipeEdge(rawValue: trashEdgeRaw) ?? AppSettings.defaultTrashEdge)
    }

    private var progress: Double {
        threshold.progress(translation: dragOffset, width: cardSize.width)
    }

    var body: some View {
        VStack(spacing: 8) {
            counterLine
            GeometryReader { proxy in
                ZStack {
                    if deck.cards.isEmpty {
                        emptyState
                    } else {
                        cardStack
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onChange(of: proxy.size, initial: true) { _, size in
                    cardSize = size
                    deck.imageTargetSize = pixelSize(size)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .overlay(alignment: .bottom) {
            actionBar
                .padding(.bottom, 14)
        }
        .onAppear {
            deck.isVisible = true
        }
        .onDisappear {
            deck.isVisible = false
        }
        .sensoryFeedback(.selection, trigger: progress >= 1) { _, isPast in
            hapticsEnabled && isPast && dragOffset != 0
        }
        .sensoryFeedback(trigger: feedback) { _, event in
            hapticsEnabled ? event.feedback : nil
        }
        .alert("Eliminazione dall'intera libreria", isPresented: $showAlbumWarning) {
            Button("Manda nel cestino", role: .destructive) {
                albumWarningShown = true
                commit(.trashed)
            }
            Button("Annulla", role: .cancel) {
                albumWarningShown = true
            }
        } message: {
            Text("Mandare nel cestino un elemento da un album significa eliminarlo dall'intera libreria, non solo dall'album, quando svuoterai il cestino.")
        }
    }

    // MARK: - Contatore

    private var counterLine: some View {
        HStack(spacing: 6) {
            if let albumTitle {
                Text(albumTitle)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("·")
            }
            if let remaining = deck.remainingCount {
                Text("\(Formatters.number(remaining)) da valutare")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(remaining)))
                    .animation(.snappy, value: remaining)
            } else {
                Text("Conteggio…")
            }
            if deck.mode == .manual {
                Text("·")
                Label(
                    deck.direction == .towardOlder ? "verso le più vecchie" : "verso le più recenti",
                    systemImage: deck.direction == .towardOlder ? "arrow.down" : "arrow.up"
                )
                .labelStyle(.titleAndIcon)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    // MARK: - Card

    private var cardStack: some View {
        ForEach(Array(deck.cards.enumerated().reversed()), id: \.element.id) { offset, card in
            let isTop = offset == 0
            SwipeCardView(
                card: card,
                isTop: isTop,
                position: "\(Formatters.number(card.item.index + 1)) / \(Formatters.number(deck.totalCount))",
                targetSize: pixelSize(cardSize),
                zoom: isTop ? zoom : ZoomState()
            )
            .overlay {
                if isTop {
                    stamp
                }
            }
            .offset(x: isTop ? dragOffset : 0)
            .rotationEffect(
                .degrees(isTop ? threshold.rotationDegrees(translation: dragOffset, width: cardSize.width) : 0),
                anchor: .bottom
            )
            .scaleEffect(isTop ? 1 : 0.94 + 0.06 * progress)
            .opacity(isTop ? 1 : 0.55 + 0.45 * progress)
            .zIndex(isTop ? 1 : 0)
            .allowsHitTesting(isTop)
            .gesture(swipeGesture(canZoom: AssetKind(card.asset).supportsZoom), including: isTop ? .all : .none)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { toggleZoom() },
                including: isTop && AssetKind(card.asset).supportsZoom ? .all : .none
            )
            .transition(.asymmetric(
                insertion: .move(edge: insertionEdge == .left ? .leading : .trailing).combined(with: .opacity),
                removal: .identity
            ))
        }
    }

    /// Etichetta "TIENI" / "CESTINO" con opacità proporzionale allo spostamento.
    @ViewBuilder
    private var stamp: some View {
        if dragOffset != 0 {
            let edge: SwipeEdge = dragOffset < 0 ? .left : .right
            let decision = layout.decision(for: edge)
            let color: Color = decision == .kept ? .green : .red
            ZStack(alignment: edge == .right ? .topLeading : .topTrailing) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(color.opacity(0.18 * progress))
                Text(decision == .kept ? "TIENI" : "CESTINO")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(color, lineWidth: 4)
                    }
                    .rotationEffect(.degrees(edge == .right ? -14 : 14))
                    .padding(.top, 96)
                    .padding(.horizontal, 28)
            }
            .opacity(progress)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Gesto

    private func swipeGesture(canZoom: Bool) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .simultaneously(with: MagnifyGesture())
            .onChanged { value in
                guard !isAnimatingOut else { return }
                if canZoom, let magnify = value.second {
                    if !zoom.isPinching {
                        zoom.isPinching = true
                        if dragOffset != 0 {
                            withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                        }
                    }
                    zoom.scale = min(max(zoom.committedScale * magnify.magnification, 0.8), 5)
                    return
                }
                guard let drag = value.first else { return }
                if zoom.isPinching || zoom.isZoomed {
                    zoom.offset = CGSize(
                        width: zoom.committedOffset.width + drag.translation.width,
                        height: zoom.committedOffset.height + drag.translation.height
                    )
                } else {
                    // Solo lo spostamento orizzontale conta: lo swipe verticale non fa nulla.
                    dragOffset = drag.translation.width
                }
            }
            .onEnded { value in
                guard !isAnimatingOut else { return }
                if zoom.isPinching || zoom.isZoomed {
                    finishZoomGesture()
                    return
                }
                guard let drag = value.first else { return }
                if let edge = threshold.committedEdge(
                    translation: drag.translation.width,
                    velocity: drag.velocity.width,
                    width: cardSize.width
                ) {
                    commit(layout.decision(for: edge))
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func finishZoomGesture() {
        zoom.isPinching = false
        if zoom.scale <= 1.01 {
            withAnimation(.spring(duration: 0.3)) {
                zoom = ZoomState()
            }
        } else {
            zoom.committedScale = zoom.scale
            zoom.committedOffset = zoom.offset
        }
    }

    private func toggleZoom() {
        withAnimation(.spring(duration: 0.3)) {
            if zoom.isZoomed {
                zoom = ZoomState()
            } else {
                zoom = ZoomState(scale: 2.5, committedScale: 2.5)
            }
        }
    }

    // MARK: - Azioni

    private func commit(_ decision: Decision) {
        guard !isAnimatingOut, deck.current != nil, cardSize.width > 0 else { return }
        if decision == .trashed, albumTitle != nil, !albumWarningShown {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                dragOffset = 0
            }
            showAlbumWarning = true
            return
        }
        let edge = layout.edge(for: decision)
        isAnimatingOut = true
        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = (edge == .left ? -1.5 : 1.5) * cardSize.width
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                deck.decide(decision)
                dragOffset = 0
                zoom = ZoomState()
            }
            isAnimatingOut = false
            feedback = feedback.next(decision == .kept ? .kept : .trashed)
        }
    }

    private func undo() {
        guard !isAnimatingOut, let action = deck.lastAction else { return }
        insertionEdge = layout.edge(for: action.decision)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            deck.undo()
            dragOffset = 0
            zoom = ZoomState()
        }
        feedback = feedback.next(.undo)
    }

    // MARK: - Barra dei pulsanti

    private var actionBar: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(spacing: 28) {
                ForEach(layout.buttonOrder, id: \.self) { button in
                    switch button {
                    case .trash:
                        GlassCircleButton(title: "Cestino", systemImage: "trash", tint: .red, isEnabled: deck.current != nil) {
                            commit(.trashed)
                        }
                    case .undo:
                        GlassCircleButton(title: "Annulla", systemImage: "arrow.uturn.backward", size: 50, isEnabled: deck.canUndo) {
                            undo()
                        }
                    case .keep:
                        GlassCircleButton(title: "Tieni", systemImage: "checkmark", tint: .green, isEnabled: deck.current != nil) {
                            commit(.kept)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stato vuoto

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                deck.mode == .manual ? "Fine della selezione" : "Hai valutato tutto",
                systemImage: "checkmark.circle"
            )
        } description: {
            Text(emptyDescription)
        } actions: {
            if deck.mode == .manual, let onExitManual {
                Button("Torna agli elementi da valutare", action: onExitManual)
                    .buttonStyle(.glass)
            }
            Button("Vai al cestino") {
                router.selectedTab = .trash
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.bottom, 90)
    }

    private var emptyDescription: String {
        if deck.totalCount == 0 {
            return albumTitle == nil ? "La libreria non contiene elementi." : "L'album non contiene elementi."
        }
        switch deck.mode {
        case .unrated:
            return "Non ci sono altri elementi da valutare. Controlla il cestino per liberare spazio."
        case .manual:
            return "Non ci sono altri elementi in questa direzione. Puoi invertire la direzione dalla barra in alto."
        }
    }

    private func pixelSize(_ size: CGSize) -> CGSize {
        CGSize(width: (size.width * displayScale).rounded(), height: (size.height * displayScale).rounded())
    }
}

/// Feedback aptico delle decisioni: ogni evento ha un numero progressivo per
/// scattare anche se la decisione si ripete.
private struct FeedbackEvent: Equatable {
    enum Kind: Equatable {
        case kept
        case trashed
        case undo
    }

    let serial: Int
    let kind: Kind?

    static let none = FeedbackEvent(serial: 0, kind: nil)

    func next(_ kind: Kind) -> FeedbackEvent {
        FeedbackEvent(serial: serial + 1, kind: kind)
    }

    var feedback: SensoryFeedback? {
        switch kind {
        case .kept: .impact(weight: .light)
        case .trashed: .impact(weight: .medium)
        case .undo: .impact(flexibility: .soft)
        case nil: nil
        }
    }
}
