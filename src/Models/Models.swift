import Foundation
import SwiftUI

// MARK: - Cleaning Categories
public enum CleanCategory: String, CaseIterable, Identifiable, Codable {
    case smartOverview = "overview"
    case systemCache = "system_cache"
    case browserCache = "browser_cache"
    case appCache = "app_cache"
    case developerDebris = "developer_debris"
    case logsAndReports = "logs_reports"
    case orphanedApps = "orphaned_apps"
    case largeAndOldFiles = "large_files"
    case trashAndDownloads = "trash_downloads"
    case settings = "settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smartOverview: return "Dashboard"
        case .systemCache: return "System & User Caches"
        case .browserCache: return "Browser Caches"
        case .appCache: return "Application Caches"
        case .developerDebris: return "Developer Debris"
        case .logsAndReports: return "Logs & Diagnostics"
        case .orphanedApps: return "Leftover App Debris"
        case .largeAndOldFiles: return "Large & Old Files"
        case .trashAndDownloads: return "Trash & Installers"
        case .settings: return "Settings & Whitelist"
        }
    }

    public var subtitle: String {
        switch self {
        case .smartOverview: return "Overview of disk state & 1-click optimization"
        case .systemCache: return "macOS user-level caches and temporary items"
        case .browserCache: return "Chrome, Safari, Brave, Arc & Firefox cache files"
        case .appCache: return "Slack, Discord, Spotify, VS Code & Electron bloat"
        case .developerDebris: return "Xcode DerivedData, npm, yarn, pip, cargo & docker caches"
        case .logsAndReports: return "Old diagnostic crash dumps and system logs"
        case .orphanedApps: return "Residual folders left behind by uninstalled applications"
        case .largeAndOldFiles: return "Files over 100 MB or untouched for months"
        case .trashAndDownloads: return "User Trash bin and leftover .dmg/.pkg installers"
        case .settings: return "Safety rules, exclusions, and custom options"
        }
    }

    public var icon: String {
        switch self {
        case .smartOverview: return "sparkles"
        case .systemCache: return "internaldrive.fill"
        case .browserCache: return "globe.americas.fill"
        case .appCache: return "square.stack.3d.up.fill"
        case .developerDebris: return "hammer.fill"
        case .logsAndReports: return "doc.plaintext.fill"
        case .orphanedApps: return "trash.slash.fill"
        case .largeAndOldFiles: return "externaldrive.badge.timemachine"
        case .trashAndDownloads: return "trash.fill"
        case .settings: return "gearshape.fill"
        }
    }

    public var color: Color {
        switch self {
        case .smartOverview: return .blue
        case .systemCache: return .teal
        case .browserCache: return .cyan
        case .appCache: return .indigo
        case .developerDebris: return .purple
        case .logsAndReports: return .orange
        case .orphanedApps: return .pink
        case .largeAndOldFiles: return Color(red: 0.92, green: 0.62, blue: 0.04) // High-contrast amber
        case .trashAndDownloads: return .red
        case .settings: return .gray
        }
    }

    public var isScannableCategory: Bool {
        return self != .smartOverview && self != .settings
    }

    public var isSafeDefault: Bool {
        switch self {
        case .systemCache, .browserCache, .appCache, .developerDebris, .logsAndReports, .trashAndDownloads:
            return true
        case .orphanedApps, .largeAndOldFiles:
            return false // User should review manually
        default:
            return false
        }
    }
}

// MARK: - Disk Item Type
public enum DiskItemType: String, Codable {
    case file
    case directory
    case appBundle
    case cacheGroup
}

// MARK: - Disk Item
public struct DiskItem: Identifiable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var path: String
    public var size: Int64
    public var category: CleanCategory
    public var subCategory: String
    public var detail: String
    public var isSelected: Bool
    public var isSafe: Bool
    public var modifiedDate: Date?
    public var itemType: DiskItemType

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: Int64,
        category: CleanCategory,
        subCategory: String,
        detail: String = "",
        isSelected: Bool = true,
        isSafe: Bool = true,
        modifiedDate: Date? = nil,
        itemType: DiskItemType = .directory
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.subCategory = subCategory
        self.detail = detail
        self.isSelected = isSelected
        self.isSafe = isSafe
        self.modifiedDate = modifiedDate
        self.itemType = itemType
    }

    public var formattedSize: String {
        DiskFormatter.formatBytes(size)
    }

    public var formattedDate: String {
        guard let date = modifiedDate else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DiskItem, rhs: DiskItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Storage Snapshot
public struct StorageSnapshot: Equatable {
    public var totalBytes: Int64 = 0
    public var freeBytes: Int64 = 0
    public var usedBytes: Int64 = 0
    public var reclaimableBytes: Int64 = 0

    public init(totalBytes: Int64 = 0, freeBytes: Int64 = 0, reclaimableBytes: Int64 = 0) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.usedBytes = max(0, totalBytes - freeBytes)
        self.reclaimableBytes = reclaimableBytes
    }

    public var formattedTotal: String {
        DiskFormatter.formatBytes(totalBytes)
    }

    public var formattedFree: String {
        DiskFormatter.formatBytes(freeBytes)
    }

    public var formattedUsed: String {
        DiskFormatter.formatBytes(usedBytes)
    }

    public var formattedReclaimable: String {
        DiskFormatter.formatBytes(reclaimableBytes)
    }

    public var percentUsed: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var percentReclaimable: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(reclaimableBytes) / Double(totalBytes)
    }
}

// MARK: - Clean Result Summary
public struct CleanSummary: Identifiable {
    public let id = UUID()
    public var bytesFreed: Int64
    public var itemsCleaned: Int
    public var errors: [String]
    public var timestamp: Date = Date()

    public var formattedBytesFreed: String {
        DiskFormatter.formatBytes(bytesFreed)
    }
}

// MARK: - Disk Formatter Helper
public enum DiskFormatter {
    public static func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Whitelist Canonicalization & Checking
public final class WhitelistManager {
    public static func canonicalize(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        return url.resolvingSymlinksInPath().standardized.path
    }

    public static func isWhitelisted(path: String, whitelist: Set<String>) -> Bool {
        let canonicalItem = canonicalize(path)
        guard !canonicalItem.isEmpty else { return false }

        for entry in whitelist {
            let canonicalEntry = canonicalize(entry)
            guard !canonicalEntry.isEmpty else { continue }
            // Exact match
            if canonicalItem == canonicalEntry { return true }
            // Directory prefix match: item is inside the whitelisted folder
            let prefix = canonicalEntry.hasSuffix("/") ? canonicalEntry : canonicalEntry + "/"
            if canonicalItem.hasPrefix(prefix) { return true }
        }
        return false
    }
}

// MARK: - System Guard: Comprehensive Path & TCC Protection
public enum SystemGuard {
    private static let homePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    private static let canonicalHome: String = URL(fileURLWithPath: homePath).resolvingSymlinksInPath().standardized.path

    public static func isProtectedPath(_ rawPath: String) -> Bool {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if trimmed == "." || trimmed == ".." { return true }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let standardURL = URL(fileURLWithPath: expanded).standardized
        let standardPath = standardURL.path
        let resolvedPath = standardURL.resolvingSymlinksInPath().standardized.path

        return checkPath(standardPath) || checkPath(resolvedPath)
    }

    private static func checkPath(_ path: String) -> Bool {
        // 1. Root & Critical System Trees
        let systemRoots: Set<String> = [
            "/", "/bin", "/sbin", "/usr", "/usr/bin", "/usr/sbin", "/usr/libexec",
            "/System", "/System/Library", "/Library", "/Applications", "/Users",
            "/private", "/private/etc", "/private/var", "/dev", "/cores", "/Volumes"
        ]
        if systemRoots.contains(path) { return true }

        if path.hasPrefix("/System/") || path.hasPrefix("/bin/") || path.hasPrefix("/sbin/") {
            return true
        }
        if path.hasPrefix("/usr/") && !path.contains("/Caches") {
            return true
        }

        // Volume mount roots
        if path.hasPrefix("/Volumes/") {
            let components = path.split(separator: "/")
            if components.count <= 2 { return true }
        }

        // 2. User Home Root
        if path == homePath || path == canonicalHome || path == "\(homePath)/" || path == "\(canonicalHome)/" {
            return true
        }

        // 3. User Standard Root Folders (protect the directories themselves from deletion)
        let protectedRoots: Set<String> = [
            "\(homePath)/Desktop", "\(homePath)/Documents", "\(homePath)/Downloads",
            "\(homePath)/Movies", "\(homePath)/Music", "\(homePath)/Pictures",
            "\(homePath)/Public", "\(homePath)/Applications",
            "\(homePath)/Library", "\(homePath)/Library/Application Support",
            "\(homePath)/Library/Containers", "\(homePath)/Library/Group Containers",
            "\(canonicalHome)/Desktop", "\(canonicalHome)/Documents", "\(canonicalHome)/Downloads",
            "\(canonicalHome)/Movies", "\(canonicalHome)/Music", "\(canonicalHome)/Pictures",
            "\(canonicalHome)/Public", "\(canonicalHome)/Applications",
            "\(canonicalHome)/Library", "\(canonicalHome)/Library/Application Support",
            "\(canonicalHome)/Library/Containers", "\(canonicalHome)/Library/Group Containers"
        ]
        if protectedRoots.contains(path) { return true }

        // 4. macOS TCC Protected & User Secrets / Credentials / Cloud Roots
        let tccAndSensitivePrefixes = [
            "\(homePath)/Library/Messages",
            "\(homePath)/Library/Mail",
            "\(homePath)/Library/HomeKit",
            "\(homePath)/Library/Safari",
            "\(homePath)/Library/Keychains",
            "\(homePath)/Library/Cookies",
            "\(homePath)/Library/Accounts",
            "\(homePath)/Library/IdentityServices",
            "\(homePath)/Library/PersonalizationPortrait",
            "\(homePath)/Library/Suggestions",
            "\(homePath)/Library/SyncedPreferences",
            "\(homePath)/Library/Mobile Documents",   // iCloud Drive containers
            "\(homePath)/Library/CloudStorage",       // iCloud Drive, Dropbox, OneDrive mounts
            "\(homePath)/Library/Application Support/MobileSync", // iPhone backups
            "\(homePath)/.ssh",
            "\(homePath)/.gnupg",
            "\(homePath)/.aws"
        ]
        for prefix in tccAndSensitivePrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") { return true }
        }

        // 5. Critical shell configuration files
        let sensitiveFiles: Set<String> = [
            "\(homePath)/.zshrc", "\(homePath)/.bashrc", "\(homePath)/.bash_profile",
            "\(homePath)/.profile", "\(homePath)/.zprofile", "\(homePath)/.gitconfig"
        ]
        if sensitiveFiles.contains(path) { return true }

        // 6. Passwords, key vaults, cookies databases
        let fileName = (path as NSString).lastPathComponent.lowercased()
        if fileName == "cookies.binarycookies" || fileName == "cookies.sqlite" ||
           fileName == "login data" || fileName == "web data" || fileName.hasSuffix(".kdbx") ||
           fileName.hasSuffix(".keychain") || fileName.hasSuffix(".keychain-db") ||
           fileName.hasPrefix("id_rsa") || fileName.hasPrefix("id_ed25519") {
            return true
        }

        return false
    }
}
