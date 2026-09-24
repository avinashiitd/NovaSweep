import Foundation
import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedCategory: CleanCategory = .smartOverview
    @Published public var items: [DiskItem] = []
    @Published public var storage: StorageSnapshot = StorageSnapshot()

    // State indicators
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var hasCompletedInitialScan: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var cleanProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready to optimize your Mac"
    @Published public var activeCleaningItem: String = ""

    // User preferences & settings
    @Published public var safeModeTrash: Bool = true
    @Published public var dryRunMode: Bool = false
    @Published public var largeFileThresholdMB: Int = 100
    @Published public var largeFileFilter: String = "All"
    @Published public var whitelist: Set<String> = []
    @Published public var searchText: String = ""

    // Modals & summaries
    @Published public var lastCleanSummary: CleanSummary? = nil
    @Published public var showCleanCompleteModal: Bool = false
    @Published public var showConfirmationAlert: Bool = false

    private let scanner = ScannerEngine()
    private let cleaner = CleanerEngine()
    private var scanTask: Task<Void, Never>? = nil

    private let whitelistKey = "NovaSweep.Whitelist"
    private let safeModeKey = "NovaSweep.SafeModeTrash"

    public init() {
        loadPreferences()
        refreshStorage()
    }

    // MARK: - Preferences
    private func loadPreferences() {
        if let saved = UserDefaults.standard.stringArray(forKey: whitelistKey) {
            self.whitelist = Set(saved.map { WhitelistManager.canonicalize($0) }.filter { !$0.isEmpty })
        }
        if UserDefaults.standard.object(forKey: safeModeKey) != nil {
            self.safeModeTrash = UserDefaults.standard.bool(forKey: safeModeKey)
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(Array(whitelist), forKey: whitelistKey)
        UserDefaults.standard.set(safeModeTrash, forKey: safeModeKey)
    }

    public func addToWhitelist(path: String) {
        let canonical = WhitelistManager.canonicalize(path)
        guard !canonical.isEmpty else { return }
        whitelist.insert(canonical)
        savePreferences()
        items.removeAll { WhitelistManager.isWhitelisted(path: $0.path, whitelist: [canonical]) }
        updateReclaimable()
    }

    public func removeFromWhitelist(path: String) {
        let canonical = WhitelistManager.canonicalize(path)
        whitelist.remove(path)
        whitelist.remove(canonical)
        savePreferences()
    }

    public func clearWhitelist() {
        whitelist.removeAll()
        savePreferences()
    }

    // MARK: - Storage Snapshot
    public func refreshStorage() {
        let reclaimable = totalSelectedBytes
        self.storage = scanner.getStorageSnapshot(reclaimable: reclaimable)
    }

    private func updateReclaimable() {
        let reclaimable = totalSelectedBytes
        self.storage.reclaimableBytes = reclaimable
    }

    // MARK: - Filtered Items & Sizes
    public func items(for category: CleanCategory) -> [DiskItem] {
        return items.filter { $0.category == category }
    }

    public func filteredItems(for category: CleanCategory) -> [DiskItem] {
        let categoryItems = items(for: category)
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return categoryItems
        }
        let query = searchText.lowercased()
        return categoryItems.filter {
            $0.name.lowercased().contains(query) ||
            $0.subCategory.lowercased().contains(query) ||
            $0.path.lowercased().contains(query)
        }
    }

    public func reclaimableBytes(for category: CleanCategory) -> Int64 {
        items.filter { $0.category == category && $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public func totalBytes(for category: CleanCategory) -> Int64 {
        items.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }

    public var totalSelectedBytes: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public var totalSelectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    public var formattedTotalSelected: String {
        DiskFormatter.formatBytes(totalSelectedBytes)
    }

    // MARK: - Selection Controls
    public func toggleItemSelection(_ id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isSelected.toggle()
            updateReclaimable()
        }
    }

    public func selectAll(for category: CleanCategory? = nil) {
        for idx in items.indices {
            if let cat = category {
                if items[idx].category == cat { items[idx].isSelected = true }
            } else {
                items[idx].isSelected = true
            }
        }
        updateReclaimable()
    }

    public func deselectAll(for category: CleanCategory? = nil) {
        for idx in items.indices {
            if let cat = category {
                if items[idx].category == cat { items[idx].isSelected = false }
            } else {
                items[idx].isSelected = false
            }
        }
        updateReclaimable()
    }

    public func selectSafeRecommended() {
        for idx in items.indices {
            items[idx].isSelected = items[idx].isSafe
        }
        updateReclaimable()
    }

    public func selectSafeOnly(for category: CleanCategory) {
        for idx in items.indices {
            if items[idx].category == category {
                items[idx].isSelected = items[idx].isSafe
            }
        }
        updateReclaimable()
    }

    // MARK: - Scanning
    public func cancelScan() {
        guard isScanning else { return }
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled."
        refreshStorage()
    }

    public func startSmartScan() {
        guard !isScanning && !isCleaning else { return }
        isScanning = true
        scanProgress = 0.0
        items = []

        scanTask = Task {
            let currentWhitelist = self.whitelist
            let threshold = Int64(self.largeFileThresholdMB) * 1024 * 1024

            self.statusMessage = "Analyzing user and system caches..."
            self.scanProgress = 0.1
            let sysCaches = await Task.detached { [scanner] in
                scanner.scanSystemCaches(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: sysCaches)

            self.statusMessage = "Scanning browser caches (Chrome, Safari, Brave)..."
            self.scanProgress = 0.25
            let browserCaches = await Task.detached { [scanner] in
                scanner.scanBrowserCaches(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: browserCaches)

            self.statusMessage = "Checking app caches (Slack, Discord, VS Code)..."
            self.scanProgress = 0.40
            let appCaches = await Task.detached { [scanner] in
                scanner.scanAppCaches(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: appCaches)

            self.statusMessage = "Auditing developer debris (Xcode, npm, pip, cargo)..."
            self.scanProgress = 0.55
            let devDebris = await Task.detached { [scanner] in
                scanner.scanDeveloperDebris(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: devDebris)

            self.statusMessage = "Collecting system logs & diagnostic reports..."
            self.scanProgress = 0.70
            let logs = await Task.detached { [scanner] in
                scanner.scanLogsAndReports(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: logs)

            self.statusMessage = "Detecting orphaned application leftovers..."
            self.scanProgress = 0.80
            let orphaned = await Task.detached { [scanner] in
                scanner.scanOrphanedApps(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: orphaned)

            self.statusMessage = "Scanning large & old files..."
            self.scanProgress = 0.90
            let largeFiles = await Task.detached { [scanner] in
                scanner.scanLargeAndOldFiles(thresholdBytes: threshold, whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: largeFiles)

            self.statusMessage = "Inspecting Trash & Download packages..."
            self.scanProgress = 0.95
            let trashItems = await Task.detached { [scanner] in
                scanner.scanTrashAndDownloads(whitelist: currentWhitelist)
            }.value
            if Task.isCancelled { return }
            self.items.append(contentsOf: trashItems)

            self.scanProgress = 1.0
            self.isScanning = false
            self.hasCompletedInitialScan = true
            self.statusMessage = "Scan complete. Found \(self.formattedTotalSelected) safe to reclaim."
            self.refreshStorage()
            self.scanTask = nil
        }
    }

    // MARK: - Cleaning
    public func startCleaning() {
        guard !isCleaning && !isScanning else { return }
        let itemsToClean = items.filter { $0.isSelected }
        guard !itemsToClean.isEmpty else { return }

        isCleaning = true
        cleanProgress = 0.0
        activeCleaningItem = "Initializing..."

        let moveToTrash = safeModeTrash
        let dryRun = dryRunMode
        let cleanerRef = self.cleaner

        Task {
            // Execute file operations in background detached task so UI is never blocked
            let summary = await Task.detached {
                await cleanerRef.clean(
                    items: itemsToClean,
                    moveToTrash: moveToTrash,
                    dryRun: dryRun
                ) { current, total, name in
                    Task { @MainActor in
                        self.cleanProgress = Double(current) / Double(total)
                        self.activeCleaningItem = name
                    }
                }
            }.value

            self.isCleaning = false
            self.lastCleanSummary = summary
            self.showCleanCompleteModal = true
            self.statusMessage = "Clean completed: \(summary.formattedBytesFreed) reclaimed."

            if !dryRun {
                let cleanedIDs = Set(itemsToClean.map { $0.id })
                self.items.removeAll { cleanedIDs.contains($0.id) }
            }
            self.refreshStorage()
        }
    }

    // MARK: - Finder Actions
    public func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    public func openItem(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
