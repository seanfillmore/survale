import SwiftUI

struct ReplayView: View {
    @State private var progress: Double = 0.0
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Replay")
                .font(.title2).bold()

            Slider(value: $progress, in: 0...1)

            HStack(spacing: 24) {
                Button {
                    // TODO: jump back
                } label: {
                    Image(systemName: "backward.fill")
                }

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }

                Button {
                    // TODO: jump forward
                } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}
