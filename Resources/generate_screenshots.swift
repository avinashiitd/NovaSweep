import SwiftUI
import AppKit

struct FullWindowMockup<Detail: View>: View {
    @ObservedObject var state: AppState
    let detailView: Detail

    init(state: AppState, @ViewBuilder detail: () -> Detail) {
        self.state = state
        self.detailView = detail()
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS Window Titlebar & Unified Toolbar
            HStack(spacing: 12) {
                // Traffic lights
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.20)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.28)).frame(width: 12, height: 12)
                }
                .padding(.leading, 14)

                Spacer()

                // App Title
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .bold))
                    Text("NovaSweep")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                // Quick Action Toolbar Buttons
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("Smart Scan")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))
                    .foregroundColor(.blue)

                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("Clean Selected")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.18)))
                    .foregroundColor(.orange)
                }
                .padding(.trailing, 14)
            }
            .frame(height: 42)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Window Content: Left Sidebar + Right Detail
            HStack(spacing: 0) {
                SidebarView(state: state)
                    .frame(width: 250)

                Divider()

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            }
        }
        .frame(width: 1080, height: 720)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

func renderViewToPNG<V: View>(view: V, outputPath: String) {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: 1080, height: 720)
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

@main
struct ScreenshotGenerator {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let outputDir = "/Users/avinash/Projects/NovaSweep/docs/screenshots"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let state = AppState()
        state.storage = StorageSnapshot(
            totalBytes: 256 * 1024 * 1024 * 1024,
            freeBytes: 68 * 1024 * 1024 * 1024,
            reclaimableBytes: 38 * 1024 * 1024 * 1024
        )

        // Populate sample items across all categories so sidebar and detail are rich
        let sampleItems: [DiskItem] = [
            // 1. Developer Debris (Total ~23 GB)
            DiskItem(name: "Xcode DerivedData", path: "/Users/developer/Library/Developer/Xcode/DerivedData", size: 14_200_000_000, category: .developerDebris, subCategory: "Xcode", detail: "Intermediate build artifacts, module caches, and indexing store", isSelected: true, isSafe: true),
            DiskItem(name: "Homebrew Bottle Cache", path: "/Users/developer/Library/Caches/Homebrew", size: 3_400_000_000, category: .developerDebris, subCategory: "Homebrew", detail: "Downloaded bottle packages and git mirrors", isSelected: true, isSafe: true),
            DiskItem(name: "NPM Cache Store", path: "/Users/developer/.npm/_cacache", size: 2_800_000_000, category: .developerDebris, subCategory: "Node.js", detail: "Global npm tarball cache", isSelected: true, isSafe: true),
            DiskItem(name: "Python Pip Wheel Cache", path: "/Users/developer/Library/Caches/pip", size: 1_900_000_000, category: .developerDebris, subCategory: "Python", detail: "Cached Python wheels from PyPI", isSelected: true, isSafe: true),
            DiskItem(name: "Cargo Registry Crates", path: "/Users/developer/.cargo/registry/cache", size: 1_200_000_000, category: .developerDebris, subCategory: "Rust", detail: "Downloaded crates.io archives", isSelected: true, isSafe: true),

            // 2. Browser Caches (Total ~4.4 GB)
            DiskItem(name: "Google Chrome Cache", path: "/Users/developer/Library/Caches/Google/Chrome", size: 2_400_000_000, category: .browserCache, subCategory: "Browser", detail: "Web pages, media, and script caches", isSelected: true, isSafe: true),
            DiskItem(name: "Arc Browser Cache", path: "/Users/developer/Library/Caches/company.thebrowser.Browser", size: 1_100_000_000, category: .browserCache, subCategory: "Browser", detail: "Arc web and tab cache", isSelected: true, isSafe: true),
            DiskItem(name: "Safari Cache", path: "/Users/developer/Library/Caches/com.apple.Safari", size: 950_000_000, category: .browserCache, subCategory: "Browser", detail: "Safari web cache and favicons", isSelected: true, isSafe: true),

            // 3. App Caches (Total ~4.3 GB)
            DiskItem(name: "Spotify Stream Cache", path: "/Users/developer/Library/Caches/com.spotify.client", size: 2_100_000_000, category: .appCache, subCategory: "App Cache", detail: "Locally buffered offline and streaming music tracks", isSelected: true, isSafe: true),
            DiskItem(name: "Slack Media Cache", path: "/Users/developer/Library/Caches/com.tinyspeck.slackmacgap", size: 1_400_000_000, category: .appCache, subCategory: "App Cache", detail: "Slack workspace images, avatar thumbnails and logs", isSelected: true, isSafe: true),
            DiskItem(name: "VS Code Cache", path: "/Users/developer/Library/Caches/com.microsoft.VSCode", size: 850_000_000, category: .appCache, subCategory: "App Cache", detail: "Extension host and workspace state cache", isSelected: true, isSafe: true),

            // 4. System & User Caches (Total ~2.1 GB)
            DiskItem(name: "QuickLook Thumbnail Cache", path: "/Users/developer/Library/Caches/com.apple.QuickLook.thumbnailcache", size: 1_500_000_000, category: .systemCache, subCategory: "User Cache", detail: "Pre-rendered Finder thumbnail previews", isSelected: true, isSafe: true),
            DiskItem(name: "Temporary App Sandboxes", path: "/Users/developer/Library/Caches/com.apple.appstore", size: 620_000_000, category: .systemCache, subCategory: "User Cache", detail: "App Store temporary update files", isSelected: true, isSafe: true),

            // 5. Logs & Reports (Total ~830 MB)
            DiskItem(name: "Diagnostic Crash Reports", path: "/Users/developer/Library/Logs/DiagnosticReports", size: 450_000_000, category: .logsAndReports, subCategory: "Diagnostics", detail: "Old application crash and hang traces", isSelected: true, isSafe: true),
            DiskItem(name: "User Logs", path: "/Users/developer/Library/Logs", size: 380_000_000, category: .logsAndReports, subCategory: "Diagnostics", detail: "Application log files and diagnostic logs", isSelected: true, isSafe: true),

            // 6. Orphaned Apps (Total ~2.0 GB)
            DiskItem(name: "ZoomResidualSupport", path: "/Users/developer/Library/Application Support/ZoomOld", size: 1_200_000_000, category: .orphanedApps, subCategory: "Application Support", detail: "Residual data for uninstalled 'ZoomOld' app", isSelected: false, isSafe: false),
            DiskItem(name: "FigmaBetaSupport", path: "/Users/developer/Library/Application Support/FigmaBeta", size: 850_000_000, category: .orphanedApps, subCategory: "Application Support", detail: "Residual data for uninstalled 'FigmaBeta' app", isSelected: false, isSafe: false),

            // 7. Large & Old Files (Total ~20.5 GB)
            DiskItem(name: "Sonoma_Install_Media.iso", path: "/Users/developer/Downloads/Sonoma_Install_Media.iso", size: 12_500_000_000, category: .largeAndOldFiles, subCategory: "DMG/PKG", detail: "Downloaded 62 days ago in ~/Downloads", isSelected: false, isSafe: false, itemType: .file),
            DiskItem(name: "Keynote_4K_Recording.mov", path: "/Users/developer/Movies/Keynote_4K_Recording.mov", size: 4_200_000_000, category: .largeAndOldFiles, subCategory: "Videos", detail: "Recorded 95 days ago in ~/Movies", isSelected: false, isSafe: false, itemType: .file),
            DiskItem(name: "Xcode_15.4_Universal.xip", path: "/Users/developer/Downloads/Xcode_15.4_Universal.xip", size: 3_800_000_000, category: .largeAndOldFiles, subCategory: "ZIP/Archives", detail: "Downloaded 45 days ago in ~/Downloads", isSelected: false, isSafe: false, itemType: .file),

            // 8. Trash (Total ~4.6 GB)
            DiskItem(name: "macOS Trash Bin", path: "/Users/developer/.Trash", size: 4_600_000_000, category: .trashAndDownloads, subCategory: "Trash", detail: "Deleted items currently consuming space in Trash", isSelected: true, isSafe: true)
        ]
        state.items = sampleItems

        // 1. Dashboard Screenshot (Overview)
        state.selectedCategory = .smartOverview
        let dashboardMockup = FullWindowMockup(state: state) {
            DashboardView(state: state)
        }
        renderViewToPNG(view: dashboardMockup, outputPath: "\(outputDir)/dashboard.png")

        // 2. Developer Debris Screenshot (Granular Category List)
        state.selectedCategory = .developerDebris
        let devMockup = FullWindowMockup(state: state) {
            CategoryDetailView(category: .developerDebris, state: state)
        }
        renderViewToPNG(view: devMockup, outputPath: "\(outputDir)/developer_debris.png")

        // 3. Large & Old Files Screenshot
        state.selectedCategory = .largeAndOldFiles
        let largeMockup = FullWindowMockup(state: state) {
            LargeFilesView(state: state)
        }
        renderViewToPNG(view: largeMockup, outputPath: "\(outputDir)/large_files.png")

        // 4. Settings & Safety Screenshot
        state.selectedCategory = .settings
        state.whitelist = [
            "/Users/developer/Projects/ConfidentialClientApp",
            "/Users/developer/.ssh"
        ]
        let settingsMockup = FullWindowMockup(state: state) {
            SettingsView(state: state)
        }
        renderViewToPNG(view: settingsMockup, outputPath: "\(outputDir)/settings.png")

        print("=== All 4 screenshots generated with full vibrant sidebar! ===")
    }
}
