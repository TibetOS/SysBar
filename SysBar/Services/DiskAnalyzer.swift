import Foundation

struct DiskEntry: Sendable, Identifiable {
    let name: String
    let path: String
    let size: UInt64
    var id: String { path }
}

actor DiskAnalyzer {
    func analyze() -> [DiskEntry] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var directories: [(String, URL)] = [
            ("Library", home.appending(path: "Library")),
            ("Applications", URL(fileURLWithPath: "/Applications")),
        ]

        // Discover hidden directories in home (e.g. .docker, .cache, .Trash)
        let knownNames = Set(directories.map { $0.1.lastPathComponent })
        if let contents = try? fm.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) {
            for url in contents {
                let name = url.lastPathComponent
                if name.hasPrefix("."), !knownNames.contains(name) {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir {
                        let displayName = name.dropFirst().prefix(1).uppercased()
                            + name.dropFirst().dropFirst()
                        directories.append((String(displayName), url))
                    }
                }
            }
        }

        var entries: [DiskEntry] = []
        var scannedTotal: UInt64 = 0

        for (name, url) in directories {
            let size = directorySize(url)
            if size > 10_000_000 {
                entries.append(DiskEntry(name: name, path: url.path, size: size))
            }
            scannedTotal += size
        }

        let totalUsed = totalDiskUsed()
        if totalUsed > scannedTotal {
            let other = totalUsed - scannedTotal
            entries.append(DiskEntry(name: "System & Other", path: "/", size: other))
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
            options: [],
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

    private func totalDiskUsed() -> UInt64 {
        var stat = statvfs()
        guard statvfs("/", &stat) == 0 else { return 0 }
        let blockSize = UInt64(stat.f_frsize)
        let total = UInt64(stat.f_blocks) * blockSize
        let free = UInt64(stat.f_bavail) * blockSize
        return total - free
    }
}
