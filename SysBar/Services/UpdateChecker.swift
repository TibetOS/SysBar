import Foundation
import AppKit

@Observable
@MainActor
final class UpdateChecker {
    static let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    private static let repoOwner = "TibetOS"
    private static let repoName = "SysBar"

    var isChecking = false
    var latestVersion: String?
    var updateURL: URL?

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true

        Task {
            defer { isChecking = false }

            guard let (version, url) = await fetchLatestRelease() else {
                showAlert(
                    title: "Update Check Failed",
                    message: "Could not reach GitHub. Please check your internet connection.",
                    showDownload: false
                )
                return
            }

            latestVersion = version
            updateURL = url

            if isNewer(version, than: Self.currentVersion) {
                showAlert(
                    title: "Update Available",
                    message: "SysBar v\(version) is available. You are running v\(Self.currentVersion).",
                    showDownload: true
                )
            } else {
                showAlert(
                    title: "You're Up to Date",
                    message: "SysBar v\(Self.currentVersion) is the latest version.",
                    showDownload: false
                )
            }
        }
    }

    private func fetchLatestRelease() async -> (String, URL)? {
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let htmlURL = json["html_url"] as? String,
              let releaseURL = URL(string: htmlURL) else {
            return nil
        }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        return (version, releaseURL)
    }

    private func showAlert(title: String, message: String, showDownload: Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                             accessibilityDescription: "SysBar")

        if showDownload, let url = updateURL {
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
