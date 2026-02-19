import SwiftUI

struct AboutView: View {
    @State private var updateChecker = UpdateChecker()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 48))
                .foregroundStyle(.primary)

            Text("SysBar")
                .font(.title)
                .fontWeight(.bold)

            Text("v\(UpdateChecker.currentVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Real-time system resource monitor\nfor your macOS menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            Button(action: { updateChecker.checkForUpdates() }) {
                HStack(spacing: 6) {
                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(updateChecker.isChecking ? "Checking..." : "Check for Updates...")
                }
            }
            .disabled(updateChecker.isChecking)

            Link("View on GitHub",
                 destination: URL(string: "https://github.com/TibetOS/SysBar")!)
                .font(.caption)
        }
        .padding(30)
        .frame(width: 280)
    }
}
