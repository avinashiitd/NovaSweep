import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Section 1: Overview
                    VStack(alignment: .leading, spacing: 3) {
                        Text("OVERVIEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                        SidebarRowButton(
                            title: CleanCategory.smartOverview.title,
                            icon: CleanCategory.smartOverview.icon,
                            color: CleanCategory.smartOverview.color,
                            badge: state.totalSelectedBytes > 0 ? state.formattedTotalSelected : nil,
                            isSelected: state.selectedCategory == .smartOverview
                        ) {
                            state.selectedCategory = .smartOverview
                        }
                    }

                    // Section 2: Clean Categories
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CLEAN CATEGORIES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 14)

                        ForEach([
                            CleanCategory.systemCache,
                            CleanCategory.browserCache,
                            CleanCategory.appCache,
                            CleanCategory.developerDebris,
                            CleanCategory.logsAndReports,
                            CleanCategory.orphanedApps,
                            CleanCategory.largeAndOldFiles,
                            CleanCategory.trashAndDownloads
                        ]) { cat in
                            let bytes = state.reclaimableBytes(for: cat)
                            SidebarRowButton(
                                title: cat.title,
                                icon: cat.icon,
                                color: cat.color,
                                badge: bytes > 0 ? DiskFormatter.formatBytes(bytes) : nil,
                                isSelected: state.selectedCategory == cat
                            ) {
                                state.selectedCategory = cat
                            }
                        }
                    }

                    // Section 3: Preferences
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PREFERENCES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 14)

                        SidebarRowButton(
                            title: CleanCategory.settings.title,
                            icon: CleanCategory.settings.icon,
                            color: CleanCategory.settings.color,
                            badge: nil,
                            isSelected: state.selectedCategory == .settings
                        ) {
                            state.selectedCategory = .settings
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()

            // Mini Disk Gauge at bottom of sidebar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Macintosh HD")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("\(state.storage.formattedFree) Free")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.18))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: max(0, min(geo.size.width * CGFloat(state.storage.percentUsed), geo.size.width)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Total: \(state.storage.formattedTotal)")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                    Spacer()
                    if state.storage.reclaimableBytes > 0 {
                        Text("+\(state.storage.formattedReclaimable) junk")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
        }
        .frame(minWidth: 230, idealWidth: 250, maxWidth: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

public struct SidebarRowButton: View {
    let title: String
    let icon: String
    let color: Color
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.28) : color.opacity(0.15)))
                        .foregroundColor(isSelected ? .white : color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
}
