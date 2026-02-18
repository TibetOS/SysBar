import Foundation

struct DiskEntry: Sendable, Identifiable {
    let name: String
    let path: String
    let size: UInt64
    var id: String { path }
}

actor DiskAnalyzer {
    func analyze() -> [DiskEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let directories: [(String, URL)] = [
            ("Desktop", home.appending(path: "Desktop")),
            ("Documents", home.appending(path: "Documents")),
            ("Downloads", home.appending(path: "Downloads")),
            ("Library", home.appending(path: "Library")),
            ("Music", home.appending(path: "Music")),
            ("Movies", home.appending(path: "Movies")),
            ("Pictures", home.appending(path: "Pictures")),
            ("Applications", URL(fileURLWithPath: "/Applications")),
        ]

        var entries: [DiskEntry] = []
        for (name, url) in directories {
            let size = directorySize(url)
            if size > 0 {
                entries.append(DiskEntry(name: name, path: url.path, size: size))
            }
        }

        entries.sort { $0.size > $1.size }
        return entries
    }

    private func directorySize(_ url: URL) -> UInt64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: Set(keys)
            ) else { continue }

            if values.isRegularFile == true {
                total += UInt64(values.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }
}
