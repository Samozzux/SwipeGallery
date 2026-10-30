import SwiftUI

/// Controlli del video come nell'app Foto: play/pausa, tempo trascorso, barra
/// di avanzamento trascinabile, tempo rimanente e audio.
struct VideoControlBar: View {
    let video: VideoPlaybackModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                video.togglePlayPause()
            } label: {
                Image(systemName: video.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(video.isPaused ? "Riproduci" : "Pausa")

            Text(Formatters.duration(video.currentTime))
                .frame(minWidth: 34, alignment: .leading)

            Slider(
                value: Binding(
                    get: { min(video.currentTime, sliderUpperBound) },
                    set: { video.scrub(to: $0) }
                ),
                in: 0 ... sliderUpperBound
            ) { isEditing in
                if isEditing {
                    video.beginScrubbing()
                } else {
                    video.endScrubbing()
                }
            }
            .disabled(video.player == nil)
            .accessibilityLabel("Avanzamento")
            .accessibilityValue("\(Formatters.duration(video.currentTime)) di \(Formatters.duration(video.duration))")

            Text("-\(Formatters.duration(max(video.duration - video.currentTime, 0)))")
                .frame(minWidth: 40, alignment: .trailing)

            Button {
                video.toggleMute()
            } label: {
                Image(systemName: video.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(video.isMuted ? "Attiva audio" : "Disattiva audio")
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    private var sliderUpperBound: Double {
        max(video.duration, 0.1)
    }
}
