import SwiftUI

struct ReplayView: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Coming Soon")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                
                Text("Operation replay and timeline features will be available in a future update")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .navigationTitle("Replay")
    }
}
