import Foundation
import AppKit

public final class ScannerEngine: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let homeURL: URL

    public init() {
        self.homeURL = FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Query Disk Overview
    public func getStorageSnapshot(reclaimable: Int64 = 0) -> StorageSnapshot {
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            var free: Int64 = 0
            if let important = values.volumeAvailableCapacityForImportantUsage {
                free = important
            } else if let avail = values.volumeAvailableCapacity {
                free = Int64(avail)
            }
            return StorageSnapshot(totalBytes: total, freeBytes: free, reclaimableBytes: reclaimable)
        } catch {
            return StorageSnapshot(totalBytes: 0, freeBytes: 0, reclaimableBytes: reclaimable)
        }
    }

    // MARK: - Safe Directory Size Calculation
    public func directorySize(at url: URL, maxDepth: Int = 4) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return attrs?[.size] as? Int64 ?? 0
        }

        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { _, _ in true } // Gracefully skip unreadable items
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard enumerator.level <= maxDepth else {
                enumerator.skipDescendants()
                continue
            }
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey]) {
                // Symlink Protection: NEVER traverse into symbolic links
                if resourceValues.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                if resourceValues.isRegularFile == true {
                    let sz = resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0
                    totalSize += Int64(sz)
                }
            }
        }
        return totalSize
    }

    // MARK: - Category 1: System & User Caches
    public func scanSystemCaches(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []
        let cachesURL = homeURL.appendingPathComponent("Library/Caches")
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cachesURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return items
        }

        // Categorized browsers and known apps handled in specific tabs
        let skippedKnownBrowsersAndApps: Set<String> = [
            "Google", "com.google.Chrome", "com.apple.Safari", "BraveSoftware", "Firefox", "Microsoft Edge",
            "company.thebrowser.Browser", "com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.spotify.client",
            "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "Homebrew", "pip", "Yarn", "CocoaPods"
        ]

        // Apple system daemons, iCloud, and security agents that must NEVER be purged
        let protectedAppleServices: [String] = [
            "com.apple.bird", "cloudkit", "com.apple.cloudkit", "com.apple.accountsd",
            "com.apple.appleaccountd", "com.apple.authenticationservices",
            "com.apple.keychain", "com.apple.security", "com.apple.passd",
            "com.apple.identityservicesd", "com.apple.cache_delete", "com.apple.findmy",
            "com.apple.homed", "com.apple.ap.adprivacyd", "com.apple.mail", "com.apple.safari"
        ]

        for itemURL in contents {
            let name = itemURL.lastPathComponent
            let lowerName = name.lowercased()

            if WhitelistManager.isWhitelisted(path: itemURL.path, whitelist: whitelist) ||
               SystemGuard.isProtectedPath(itemURL.path) ||
               skippedKnownBrowsersAndApps.contains(name) {
                continue
            }

            var isProtectedDaemon = false
            for svc in protectedAppleServices {
                if lowerName.contains(svc) {
                    isProtectedDaemon = true
                    break
                }
            }
            if isProtectedDaemon { continue }

            let size = directorySize(at: itemURL, maxDepth: 3)
            if size > 1_000_000 { // 1 MB threshold
                let modDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                items.append(DiskItem(
                    name: name,
                    path: itemURL.path,
                    size: size,
                    category: .systemCache,
                    subCategory: "User Cache",
                    detail: "Cache generated by \(name)",
                    isSelected: true,
                    isSafe: true,
                    modifiedDate: modDate
                ))
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 2: Browser Caches
    public func scanBrowserCaches(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        let targets: [(name: String, relPath: String, desc: String)] = [
            ("Google Chrome Cache", "Library/Caches/Google/Chrome", "Web pages, media, and script caches"),
            ("Safari Cache", "Library/Caches/com.apple.Safari", "Safari web cache and favicons"),
            ("Brave Browser Cache", "Library/Caches/BraveSoftware/Brave-Browser", "Cached web data"),
            ("Mozilla Firefox Cache", "Library/Caches/Firefox", "Firefox network cache"),
            ("Microsoft Edge Cache", "Library/Caches/Microsoft Edge", "Edge browser cache"),
            ("Arc Browser Cache", "Library/Caches/company.thebrowser.Browser", "Arc web and tab cache")
        ]

        for target in targets {
            let targetURL = homeURL.appendingPathComponent(target.relPath)
            if fileManager.fileExists(atPath: targetURL.path) &&
               !WhitelistManager.isWhitelisted(path: targetURL.path, whitelist: whitelist) &&
               !SystemGuard.isProtectedPath(targetURL.path) {
                let size = directorySize(at: targetURL)
                if size > 500_000 {
                    let modDate = (try? targetURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(DiskItem(
                        name: target.name,
                        path: targetURL.path,
                        size: size,
                        category: .browserCache,
                        subCategory: "Browser",
                        detail: target.desc,
                        isSelected: true,
                        isSafe: true,
                        modifiedDate: modDate
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 3: Application Caches
    public func scanAppCaches(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        // Strictly target legitimate cache folders under ~/Library/Caches/*
        let targets: [(name: String, relPath: String, desc: String)] = [
            ("Slack Cache", "Library/Caches/com.tinyspeck.slackmacgap", "Slack media, channel thumbnails and logs"),
            ("Discord Cache", "Library/Caches/com.hnc.Discord", "Discord cached voice and chat images"),
            ("Spotify Cache", "Library/Caches/com.spotify.client", "Locally stored music stream buffer"),
            ("VS Code Cache", "Library/Caches/com.microsoft.VSCode", "Extension and workspace cache"),
            ("Cursor Cache", "Library/Caches/com.todesktop.230313mzl4w4u92", "Cursor AI editor cached state"),
            ("Zoom Cache", "Library/Caches/us.zoom.xos", "Meeting temporary files and thumbnails"),
            ("Microsoft Teams Cache", "Library/Caches/com.microsoft.teams2", "Teams cache database and media"),
            ("Notion Cache", "Library/Caches/notion.id", "Notion desktop offline cache"),
            ("Telegram Cache", "Library/Caches/ru.keepcoder.Telegram", "Telegram media and message cache")
        ]

        for target in targets {
            let targetURL = homeURL.appendingPathComponent(target.relPath)
            if fileManager.fileExists(atPath: targetURL.path) &&
               !WhitelistManager.isWhitelisted(path: targetURL.path, whitelist: whitelist) &&
               !SystemGuard.isProtectedPath(targetURL.path) {
                let size = directorySize(at: targetURL)
                if size > 500_000 {
                    let modDate = (try? targetURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(DiskItem(
                        name: target.name,
                        path: targetURL.path,
                        size: size,
                        category: .appCache,
                        subCategory: "App Cache",
                        detail: target.desc,
                        isSelected: true,
                        isSafe: true,
                        modifiedDate: modDate
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 4: Developer Debris
    public func scanDeveloperDebris(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        let devTargets: [(name: String, relPath: String, subCat: String, desc: String)] = [
            ("Xcode DerivedData", "Library/Developer/Xcode/DerivedData", "Xcode", "Intermediate build files and index data"),
            ("Xcode Archives", "Library/Developer/Xcode/Archives", "Xcode", "Past build archives and dSYMs"),
            ("Xcode iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport", "Xcode", "Legacy iOS device debugging symbols"),
            ("Homebrew Cache", "Library/Caches/Homebrew", "Homebrew", "Downloaded bottle archives and git clones"),
            ("NPM Cache", ".npm/_cacache", "Node.js", "Cached package tarballs"),
            ("Yarn Cache", ".yarn/cache", "Node.js", "Offline package storage"),
            ("Yarn Library Cache", "Library/Caches/Yarn", "Node.js", "Global yarn cache"),
            ("pnpm Store", "Library/pnpm/store", "Node.js", "Hard-linked package store"),
            ("Python Pip Cache", "Library/Caches/pip", "Python", "Downloaded wheel archives"),
            ("Python Pip Hidden Cache", ".cache/pip", "Python", "Local pip wheel download cache"),
            ("Rust Cargo Cache", ".cargo/registry/cache", "Rust", "Downloaded crates.io .crate archives"),
            ("Gradle Cache", ".gradle/caches", "Java / Android", "Dependency caches and wrapper binaries"),
            ("CocoaPods Cache", "Library/Caches/CocoaPods", "iOS / Mac", "Pods repository clone cache")
        ]

        for target in devTargets {
            let targetURL = homeURL.appendingPathComponent(target.relPath)
            if fileManager.fileExists(atPath: targetURL.path) &&
               !WhitelistManager.isWhitelisted(path: targetURL.path, whitelist: whitelist) &&
               !SystemGuard.isProtectedPath(targetURL.path) {
                let size = directorySize(at: targetURL)
                if size > 1_000_000 { // > 1MB
                    let modDate = (try? targetURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(DiskItem(
                        name: target.name,
                        path: targetURL.path,
                        size: size,
                        category: .developerDebris,
                        subCategory: target.subCat,
                        detail: target.desc,
                        isSelected: true,
                        isSafe: true,
                        modifiedDate: modDate
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 5: Logs & Diagnostic Reports
    public func scanLogsAndReports(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        // Mail Downloads intentionally excluded to avoid TCC Full Disk Access / Mail prompts
        let logsTargets: [(name: String, relPath: String, desc: String)] = [
            ("User Logs", "Library/Logs", "Application log files and diagnostic traces"),
            ("Diagnostic Crash Reports", "Library/Logs/DiagnosticReports", "Old application crash and hang reports"),
            ("CrashReporter Storage", "Library/Application Support/CrashReporter", "Saved system crash reports")
        ]

        for target in logsTargets {
            let targetURL = homeURL.appendingPathComponent(target.relPath)
            if fileManager.fileExists(atPath: targetURL.path) &&
               !WhitelistManager.isWhitelisted(path: targetURL.path, whitelist: whitelist) &&
               !SystemGuard.isProtectedPath(targetURL.path) {
                let size = directorySize(at: targetURL)
                if size > 100_000 {
                    let modDate = (try? targetURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(DiskItem(
                        name: target.name,
                        path: targetURL.path,
                        size: size,
                        category: .logsAndReports,
                        subCategory: "Diagnostics",
                        detail: target.desc,
                        isSelected: true,
                        isSafe: true,
                        modifiedDate: modDate
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 6: Orphaned App Leftovers
    public func scanOrphanedApps(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        // 1. Gather installed app bundle base names
        var installedApps: Set<String> = []
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            homeURL.appendingPathComponent("Applications")
        ]

        for dir in appDirs {
            if let urls = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for url in urls where url.pathExtension == "app" {
                    let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
                    installedApps.insert(baseName)
                    installedApps.insert(baseName.replacingOccurrences(of: " ", with: ""))
                }
            }
        }

        // Expanded system and privacy folders in Application Support that must NEVER be flagged as orphaned
        let systemIgnored: Set<String> = [
            "apple", "com.apple", "addressbook", "syncservices", "dock", "finder", "icdd",
            "cloudkit", "app store", "audio", "quick look", "itunes", "callhistorydb", "preferences",
            "google", "microsoft", "antigravity-cli", "mobilesync", "messages", "mail", "homekit",
            "safari", "fileprovider", "clouddocs", "knowledge", "biome", "identityservices",
            "accounts", "coresimulator", "1password", "bitwarden", "keepass", "lastpass",
            "gnupg", "gpg", "keychain", "security", "bluetooth", "notificationcenter",
            "spotlight", "containers", "group containers", "cloudstorage", "code", "cursor",
            "sublime text", "jetbrains", "intellij", "steam", "postman", "docker"
        ]

        // 2. Scan ~/Library/Application Support
        let appSupportURL = homeURL.appendingPathComponent("Library/Application Support")
        if let appSupportDirs = try? fileManager.contentsOfDirectory(
            at: appSupportURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) {
            let sixtyDaysAgo = Date(timeIntervalSinceNow: -60 * 24 * 3600)

            for dir in appSupportDirs {
                let name = dir.lastPathComponent
                let lowerName = name.lowercased().replacingOccurrences(of: " ", with: "")

                var isSystem = false
                for sys in systemIgnored {
                    if lowerName.contains(sys) {
                        isSystem = true
                        break
                    }
                }
                if isSystem ||
                   WhitelistManager.isWhitelisted(path: dir.path, whitelist: whitelist) ||
                   SystemGuard.isProtectedPath(dir.path) {
                    continue
                }

                // Check modification date: only flag if untouched for > 60 days
                let modDate = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let mod = modDate, mod > sixtyDaysAgo {
                    continue // Actively used recently
                }

                // Check if any installed app name matches
                var matchesInstalled = false
                for installed in installedApps {
                    if lowerName.contains(installed) || installed.contains(lowerName) {
                        matchesInstalled = true
                        break
                    }
                }

                if !matchesInstalled {
                    let size = directorySize(at: dir, maxDepth: 3)
                    if size > 5_000_000 { // > 5 MB
                        items.append(DiskItem(
                            name: name,
                            path: dir.path,
                            size: size,
                            category: .orphanedApps,
                            subCategory: "Application Support",
                            detail: "Residual data for '\(name)' (no installed app found, untouched >60 days)",
                            isSelected: false, // Default to unchecked for safety
                            isSafe: false,
                            modifiedDate: modDate
                        ))
                    }
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 7: Large & Old Files
    public func scanLargeAndOldFiles(thresholdBytes: Int64 = 100 * 1024 * 1024, whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        // Documents and Desktop are excluded from default automated scans to avoid TCC prompts
        let candidateFolders = [
            homeURL.appendingPathComponent("Downloads"),
            homeURL.appendingPathComponent("Movies"),
            homeURL.appendingPathComponent("Music")
        ]

        for folder in candidateFolders {
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .totalFileAllocatedSizeKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if enumerator.level > 3 {
                    enumerator.skipDescendants()
                    continue
                }

                if WhitelistManager.isWhitelisted(path: fileURL.path, whitelist: whitelist) ||
                   SystemGuard.isProtectedPath(fileURL.path) {
                    continue
                }

                if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .totalFileAllocatedSizeKey]) {
                    // Symlink protection
                    if values.isSymbolicLink == true {
                        enumerator.skipDescendants()
                        continue
                    }

                    if values.isRegularFile == true {
                        let sz = values.totalFileAllocatedSize ?? values.fileSize ?? 0
                        if Int64(sz) >= thresholdBytes {
                            let ext = fileURL.pathExtension.uppercased()
                            let subCat = ext.isEmpty ? "Large File" : "\(ext) File"
                            let modDate = values.contentModificationDate

                            items.append(DiskItem(
                                name: fileURL.lastPathComponent,
                                path: fileURL.path,
                                size: Int64(sz),
                                category: .largeAndOldFiles,
                                subCategory: subCat,
                                detail: "Located in ~/\(folder.lastPathComponent)",
                               isSelected: false, // Safety: user selects explicitly
                                isSafe: false,
                                modifiedDate: modDate,
                                itemType: .file
                            ))
                        }
                    }
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Category 8: Trash & Installers
    public func scanTrashAndDownloads(whitelist: Set<String>) -> [DiskItem] {
        var items: [DiskItem] = []

        // 1. User Trash
        let trashURL = homeURL.appendingPathComponent(".Trash")
        if fileManager.fileExists(atPath: trashURL.path) {
            var trashSize = directorySize(at: trashURL, maxDepth: 4)
            var trashDetail = "Items deleted but still consuming storage in macOS Trash"

            // Fallback for TCC: If direct file enumeration failed (due to restricted .Trash permissions), query Finder
            if trashSize == 0 {
                let countScript = NSAppleScript(source: "tell application \"Finder\" to get count of items in trash")
                if let countStr = countScript?.executeAndReturnError(nil).stringValue,
                   let count = Int(countStr), count > 0 {
                    // Query estimated size from Finder
                    let sizeScript = NSAppleScript(source: """
                    tell application "Finder"
                        try
                            set trashItems to items of trash
                            set totalSize to 0
                            repeat with itm in trashItems
                                try
                                    set totalSize to totalSize + (size of itm)
                                end try
                            end repeat
                            return totalSize as string
                        on error
                            return "0"
                        end try
                    end tell
                    """)
                    let sizeStr = sizeScript?.executeAndReturnError(nil).stringValue ?? "0"
                    let computedSize = Int64(Double(sizeStr) ?? 0)
                    trashSize = max(computedSize, Int64(count) * 1024)
                    trashDetail = "\(count) item\(count == 1 ? "" : "s") pending deletion in macOS Trash"
                }
            }

            if trashSize > 0 {
                items.append(DiskItem(
                    name: "macOS Trash Bin",
                    path: trashURL.path,
                    size: trashSize,
                    category: .trashAndDownloads,
                    subCategory: "Trash",
                    detail: trashDetail,
                    isSelected: true,
                    isSafe: true
                ))
            }
        }

        // 2. Installers in Downloads (.dmg, .pkg, .iso)
        let downloadsURL = homeURL.appendingPathComponent("Downloads")
        if let contents = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .totalFileAllocatedSizeKey],
            options: .skipsHiddenFiles
        ) {
            let installerExts: Set<String> = ["dmg", "pkg", "iso", "zip", "tar", "gz"]
            let calendar = Calendar.current
            let now = Date()

            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                if installerExts.contains(ext) &&
                   !WhitelistManager.isWhitelisted(path: fileURL.path, whitelist: whitelist) &&
                   !SystemGuard.isProtectedPath(fileURL.path) {
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .totalFileAllocatedSizeKey]),
                       let size = values.totalFileAllocatedSize ?? values.fileSize,
                       Int64(size) > 10_000_000 { // > 10 MB

                        let modDate = values.contentModificationDate
                        let daysOld = modDate.flatMap { calendar.dateComponents([.day], from: $0, to: now).day } ?? 0

                        items.append(DiskItem(
                            name: fileURL.lastPathComponent,
                            path: fileURL.path,
                            size: Int64(size),
                            category: .trashAndDownloads,
                            subCategory: "\(ext.uppercased()) Installer",
                            detail: "Downloaded \(daysOld) days ago in ~/Downloads",
                            isSelected: daysOld > 14, // Automatically check if older than 2 weeks
                            isSafe: true,
                            modifiedDate: modDate,
                            itemType: .file
                        ))
                    }
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }
}
