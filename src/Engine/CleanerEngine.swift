import Foundation
import AppKit

public final class CleanerEngine: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let homePath: String

    public init() {
        self.homePath = FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Unlock a file or directory tree by clearing user immutable flags
    private func unlockItem(at url: URL) {
        var vals = URLResourceValues()
        vals.isUserImmutable = false
        var mutableURL = url
        try? mutableURL.setResourceValues(vals)

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isUserImmutableKey],
            options: [.skipsPackageDescendants]
        ) {
            for case let subURL as URL in enumerator {
                var subMutable = subURL
                try? subMutable.setResourceValues(vals)
            }
        }
    }

    /// Safely empty macOS Trash using direct removal or Finder AppleScript fallback
    private func emptyTrash(at trashURL: URL) -> (success: Bool, errorMsg: String?) {
        // Attempt 1: Direct contents enumeration (works if FDA is granted)
        if let contents = try? fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) {
            var anyFailed = false
            for item in contents {
                do {
                    try fileManager.removeItem(at: item)
                } catch {
                    unlockItem(at: item)
                    do {
                        try fileManager.removeItem(at: item)
                    } catch {
                        anyFailed = true
                    }
                }
            }
            if !anyFailed {
                return (true, nil)
            }
        }

        // Attempt 2: AppleScript Finder command (standard macOS privileged automation)
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: "tell application \"Finder\" to empty trash without warnings")
        if let _ = script?.executeAndReturnError(&errorDict) {
            return (true, nil)
        } else {
            let msg = errorDict?[NSAppleScript.errorMessage] as? String ?? "Trash could not be emptied by Finder"
            return (false, msg)
        }
    }

    public func clean(
        items: [DiskItem],
        moveToTrash: Bool = true,
        dryRun: Bool = false,
        onProgress: @escaping (Int, Int, String) -> Void
    ) async -> CleanSummary {
        var bytesFreed: Int64 = 0
        var itemsCleaned: Int = 0
        var errors: [String] = []

        let total = items.count

        for (index, item) in items.enumerated() {
            onProgress(index + 1, total, item.name)

            // 1. Strict System Guard: verify path is not protected
            if SystemGuard.isProtectedPath(item.path) {
                errors.append("Blocked attempt to clean protected path: \(item.path)")
                continue
            }

            if dryRun {
                bytesFreed += item.size
                itemsCleaned += 1
                try? await Task.sleep(nanoseconds: 20_000_000)
                continue
            }

            let itemURL = URL(fileURLWithPath: item.path)
            guard fileManager.fileExists(atPath: itemURL.path) else {
                continue
            }

            // 2. Symlink Protection:
            // Check if item itself is a symbolic link
            let isSymlink: Bool = {
                let vals = try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                return vals?.isSymbolicLink == true
            }()

            if isSymlink {
                // Check where the symlink points to make sure its destination is not a protected path
                let resolvedTarget = itemURL.resolvingSymlinksInPath().path
                if SystemGuard.isProtectedPath(resolvedTarget) {
                    errors.append("Blocked symlink targeting protected system path: \(item.path) -> \(resolvedTarget)")
                    continue
                }

                // Deleting the symlink must ONLY remove the link itself, never traverse to destination!
                do {
                    try fileManager.removeItem(at: itemURL)
                    bytesFreed += item.size
                    itemsCleaned += 1
                } catch {
                    errors.append("Could not remove symlink \(item.name): \(error.localizedDescription)")
                }
                continue
            }

            // 3. Regular Items & Trash
            do {
                if item.path.hasSuffix("/.Trash") || item.name == "macOS Trash Bin" {
                    let trashResult = emptyTrash(at: itemURL)
                    if trashResult.success {
                        bytesFreed += item.size
                        itemsCleaned += 1
                    } else {
                        errors.append("Could not fully empty Trash: \(trashResult.errorMsg ?? "Permission denied")")
                    }
                } else if moveToTrash {
                    // Safe removal: Move to macOS Trash with lock fallback
                    do {
                        try fileManager.trashItem(at: itemURL, resultingItemURL: nil)
                        bytesFreed += item.size
                        itemsCleaned += 1
                    } catch {
                        // Fallback: file might be locked; unlock and retry
                        unlockItem(at: itemURL)
                        do {
                            try fileManager.trashItem(at: itemURL, resultingItemURL: nil)
                            bytesFreed += item.size
                            itemsCleaned += 1
                        } catch {
                            // Do NOT permanently delete if user requested Safe Mode Trash
                            errors.append("Could not move \(item.name) to Trash: \(error.localizedDescription). File preserved for safety.")
                        }
                    }
                } else {
                    // Permanent delete with lock fallback
                    do {
                        try fileManager.removeItem(at: itemURL)
                        bytesFreed += item.size
                        itemsCleaned += 1
                    } catch {
                        unlockItem(at: itemURL)
                        do {
                            try fileManager.removeItem(at: itemURL)
                            bytesFreed += item.size
                            itemsCleaned += 1
                        } catch {
                            errors.append("Could not delete \(item.name): \(error.localizedDescription)")
                        }
                    }
                }
            }

            // Yield thread periodically for smooth UI responsiveness
            if index % 5 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        return CleanSummary(
            bytesFreed: bytesFreed,
            itemsCleaned: itemsCleaned,
            errors: errors,
            timestamp: Date()
        )
    }
}
