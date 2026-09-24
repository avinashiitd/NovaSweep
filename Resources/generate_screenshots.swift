import SwiftUI
import AppKit

struct WindowMockup<Detail: View>: View {
    @ObservedObject var state: AppState
    let detailView: Detail

    init(state: AppState, @ViewBuilder detail: () -> Detail) {
        self.state = state
        self.detailView = detail()
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS Titlebar
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.20)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.28)).frame(width: 12, height: 12)
                }
                .padding(.leading, 12)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("NovaSweep")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                // Toolbar Actions
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Smart Scan")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))
                    .foregroundColor(.blue)

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Clean Selected")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.15)))
                    .foregroundColor(.orange)
                }
                .padding(.trailing, 12)
            }
            .frame(height: 40)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content: Split Sidebar + Detail
            HStack(spacing: 0) {
                SidebarView(state: state)
                    .frame(width: 250)

                Divider()

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 1040, height: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

func renderViewToPNG<V: View>(view: V, outputPath: String) {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: 1040, height: 680)
    hostingView.layoutSubtreeIfNeeded()

    guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        print("Failed to allocate bitmap rep for \(outputPath)")
        return
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("✓ Created: \(outputPath) (\(pngData.count / 1024) KB)")
    }
}

@MainActor
func generateAllScreenshots() {
    let outputDir = "/Users/avinash/Projects/NovaSweep/docs/screenshots"
    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    let state = AppState()
    state.storage = StorageSnapshot(totalBytes: 256 * 1024 * 1024 * 1024, freeBytes: 68 * 1024 * 1024 * 1024, reclaimableBytes: 31 * 1024 * 1024 * 1024)

    // Populate mock scanned items
    let sampleItems: [DiskItem] = [
        // Developer Debris
        DiskItem(name: "Xcode DerivedData", path: "/Users/developer/Library/Developer/Xcode/DerivedData", size: 14_200_000_000, category: .developerDebris, subCategory: "Xcode", detail: "Intermediate build files, module caches, and index stores", isSelected: true, isSafe: true),
        DiskItem(name: "NPM Package Cache", path: "/Users/developer/.npm/_cacache", size: 2_800_000_000, category: .developerDebris, subCategory: "Node.js", detail: "Global package tarball cache", isSelected: true, isSafe: true),
        DiskItem(name: "Python Pip Cache", path: "/Users/developer/Library/Caches/pip", size: 1_900_000_000, category: .developerDebris, subCategory: "Python", detail: "Downloaded Python wheel archives", isSelected: true, isSafe: true),
        DiskItem(name: "Homebrew Bottles", path: "/Users/developer/Library/Caches/Homebrew", size: 3_400_000_000, category: .developerDebris, subCategory: "Homebrew", detail: "Cached bottle downloads and git repositories", isSelected: true, isSafe: true),
        DiskItem(name: "Cargo Crates Cache", path: "/Users/developer/.cargo/registry/cache", size: 1_200_000_000, category: .developerDebris, subCategory: "Rust", detail: "Downloaded crates.io archives", isSelected: true, isSafe: true),

        // Browser Caches
        DiskItem(name: "Google Chrome Cache", path: "/Users/developer/Library/Caches/Google/Chrome", size: 2_400_000_000, category: .browserCache, subCategory: "Browser", detail: "Web pages, media, and script caches", isSelected: true, isSafe: true),
        DiskItem(name: "Safari Cache", path: "/Users/developer/Library/Caches/com.apple.Safari", size: 950_000_000, category: .browserCache, subCategory: "Browser", detail: "Safari web cache and favicons", isSelected: true, isSafe: true),
        DiskItem(name: "Arc Browser Cache", path: "/Users/developer/Library/Caches/company.thebrowser.Browser", size: 1_100_000_000, category: .browserCache, subCategory: "Browser", detail: "Arc web and tab cache", isSelected: true, isSafe: true),

        // App Caches
        DiskItem(name: "Slack Cache", path: "/Users/developer/Library/Caches/com.tinyspeck.slackmacgap", size: 1_400_000_000, category: .appCache, subCategory: "App Cache", detail: "Slack media, channel thumbnails and logs", isSelected: true, isSafe: true),
        DiskItem(name: "Spotify Stream Cache", path: "/Users/developer/Library/Caches/com.spotify.client", size: 2_100_000_000, category: .appCache, subCategory: "App Cache", detail: "Locally stored music stream buffer", isSelected: true, isSafe: true),
        DiskItem(name: "VS Code Cache", path: "/Users/developer/Library/Caches/com.microsoft.VSCode", size: 850_000_000, category: .appCache, subCategory: "App Cache", detail: "Extension and workspace cache", isSelected: true, isSafe: true),

        // System & Logs
        DiskItem(name: "Diagnostic Crash Reports", path: "/Users/developer/Library/Logs/DiagnosticReports", size: 450_000_000, category: .logsAndReports, subCategory: "Diagnostics", detail: "Old application crash and hang reports", isSelected: true, isSafe: true),
        DiskItem(name: "User Logs", path: "/Users/developer/Library/Logs", size: 380_000_000, category: .logsAndReports, subCategory: "Diagnostics", detail: "Application log files and diagnostic traces", isSelected: true, isSafe: true),

        // Orphaned Apps
        DiskItem(name: "OldZoomClient", path: "/Users/developer/Library/Application Support/ZoomOld", size: 1_200_000_000, category: .orphanedApps, subCategory: "Application Support", detail: "Residual data for 'ZoomOld' (no installed app found)", isSelected: false, isSafe: false),
        DiskItem(name: "LegacyFigmaCache", path: "/Users/developer/Library/Application Support/FigmaBeta", size: 850_000_000, category: .orphanedApps, subCategory: "Application Support", detail: "Residual data for 'FigmaBeta' (no installed app found)", isSelected: false, isSafe: false),

        // Large Files
        DiskItem(name: "Xcode_15.4_Universal.xip", path: "/Users/developer/Downloads/Xcode_15.4_Universal.xip", size: 3_800_000_000, category: .largeAndOldFiles, subCategory: "ZIP/Archives", detail: "Downloaded 45 days ago in ~/Downloads", isSelected: false, isSafe: false, itemType: .file),
        DiskItem(name: "Sonoma_Install_Media.iso", path: "/Users/developer/Downloads/Sonoma_Install_Media.iso", size: 12_500_000_000, category: .largeAndOldFiles, subCategory: "DMG/PKG", detail: "Downloaded 62 days ago in ~/Downloads", isSelected: false, isSafe: false, itemType: .file),
        DiskItem(name: "Keynote_4K_Recording.mov", path: "/Users/developer/Movies/Keynote_4K_Recording.mov", size: 4_200_000_000, category: .largeAndOldFiles, subCategory: "Videos", detail: "Located in ~/Movies", isSelected: false, isSafe: false, itemType: .file),

        // Trash
        DiskItem(name: "macOS Trash Bin", path: "/Users/developer/.Trash", size: 4_600_000_000, category: .trashAndDownloads, subCategory: "Trash", detail: "Items deleted but still consuming storage in Trash", isSelected: true, isSafe: true)
    ]
    state.items = sampleItems

    // 1. Dashboard Screenshot
    state.selectedCategory = .smartOverview
    let dashboardMockup = WindowMockup(state: state) {
        DashboardView(state: state)
    }
    renderViewToPNG(view: dashboardMockup, outputPath: "\(outputDir)/dashboard.png")

    // 2. Developer Debris Screenshot
    state.selectedCategory = .developerDebris
    let devMockup = WindowMockup(state: state) {
        CategoryDetailView(category: .developerDebris, state: state)
    }
    renderViewToPNG(view: devMockup, outputPath: "\(outputDir)/developer_debris.png")

    // 3. Large Files Screenshot
    state.selectedCategory = .largeAndOldFiles
    let largeMockup = WindowMockup(state: state) {
        LargeFilesView(state: state)
    }
    renderViewToPNG(view: largeMockup, outputPath: "\(outputDir)/large_files.png")

    // 4. Settings & Safety Screenshot
    state.selectedCategory = .settings
    state.whitelist = ["/Users/developer/Projects/SensitiveProject", "/Users/developer/.ssh"]
    let settingsMockup = WindowMockup(state: state) {
        SettingsView(state: state)
    }
    renderViewToPNG(view: settingsMockup, outputPath: "\(outputDir)/settings.png")

    print("All screenshots generated successfully in \(outputDir)")
}

@main
struct ScreenshotGenerator {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        generateAllScreenshots()
    }
}
