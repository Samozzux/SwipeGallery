import SwiftUI

/// Selettore Swipe / Griglia in Liquid Glass, con l'evidenziazione che scorre
/// fra le due voci.
struct ModeSwitcher: View {
    @Binding var selection: BrowserMode
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                ForEach(BrowserMode.allCases) { mode in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selection = mode
                        }
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                            .background {
                                if selection == mode {
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.22))
                                        .matchedGeometryEffect(id: "selection", in: namespace)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
                }
            }
            .padding(3)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}

/// Etichetta informativa in vetro sopra al contenuto.
struct GlassChip<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }
}

/// Pulsante circolare in vetro, con tinta opzionale.
struct GlassCircleButton: View {
    let title: String
    let systemImage: String
    var tint: Color?
    var size: CGFloat = 64
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint ?? Color.primary)
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint?.opacity(0.18)).interactive(), in: .circle)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
