import SwiftUI
import AppKit

@main
struct NovaSweepApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(state: appState)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
            } detail: {
                detailView(for: appState.selectedCategory)
                    .frame(minWidth: 700, idealWidth: 800, minHeight: 540, idealHeight: 660)
            }
            .frame(minWidth: 960, minHeight: 620)
            .navigationTitle("NovaSweep")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if appState.isScanning {
                        Button {
                            appState.cancelScan()
                        } label: {
                            Label("Cancel Scan", systemImage: "xmark.circle")
                        }
                        .keyboardShortcut(".", modifiers: .command)
                        .help("Cancel Running Scan (⌘.)")
                    } else {
                        Button {
                            appState.startSmartScan()
                        } label: {
                            Label("Smart Scan", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .keyboardShortcut("r", modifiers: .command)
                        .disabled(appState.isCleaning)
                        .help("Run Smart Scan (⌘R)")
                    }

                    Button {
                        appState.showConfirmationAlert = true
                    } label: {
                        Label("Clean Selected", systemImage: "sparkles")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(appState.totalSelectedBytes == 0 || appState.isScanning || appState.isCleaning)
                    .help("Clean Selected Items (⌘K)")
                }
            }
            .sheet(isPresented: $appState.showCleanCompleteModal) {
                CleanCompleteModal(
                    summary: appState.lastCleanSummary,
                    isDryRun: appState.dryRunMode
                ) {
                    appState.showCleanCompleteModal = false
                }
            }
            .alert("Confirm Disk Optimization", isPresented: $appState.showConfirmationAlert) {
                Button("Proceed with Cleanup", role: .destructive) {
                    appState.startCleaning()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if appState.dryRunMode {
                    Text("Dry Run Mode is active: NovaSweep will simulate cleaning \(appState.formattedTotalSelected) across \(appState.totalSelectedCount) items without altering any files.")
                } else if appState.safeModeTrash {
                    Text("NovaSweep will safely move \(appState.formattedTotalSelected) across \(appState.totalSelectedCount) items to your macOS Trash. You can easily inspect or restore them from the Trash if needed.")
                } else {
                    Text("Warning: Safe Trash Mode is disabled. \(appState.formattedTotalSelected) across \(appState.totalSelectedCount) items will be PERMANENTLY deleted. Are you sure you want to proceed?")
                }
            }
        }
        .defaultSize(width: 1060, height: 720)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan & Clean") {
                Button("Smart Scan") {
                    appState.startSmartScan()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.isScanning || appState.isCleaning)

                if appState.isScanning {
                    Button("Cancel Scan") {
                        appState.cancelScan()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                }

                Button("Clean Selected Items") {
                    if appState.totalSelectedBytes > 0 {
                        appState.showConfirmationAlert = true
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(appState.totalSelectedBytes == 0 || appState.isScanning || appState.isCleaning)

                Divider()

                Button("Select All Items") {
                    appState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("Deselect All Items") {
                    appState.deselectAll()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Select Safe Recommendations") {
                    appState.selectSafeRecommended()
                }

                Divider()

                Toggle("Dry Run Mode", isOn: $appState.dryRunMode)
                Toggle("Safe Mode (Move to Trash)", isOn: $appState.safeModeTrash)
            }
        }
    }

    @ViewBuilder
    private func detailView(for category: CleanCategory) -> some View {
        switch category {
        case .smartOverview:
            DashboardView(state: appState)
        case .largeAndOldFiles:
            LargeFilesView(state: appState)
        case .settings:
            SettingsView(state: appState)
        default:
            CategoryDetailView(category: category, state: appState)
        }
    }
}
