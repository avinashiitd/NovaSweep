import SwiftUI

public struct SidebarView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.selectedCategory) {
                Section("Overview") {
                    NavigationLink(value: CleanCategory.smartOverview) {
                        Label {
                            HStack {
                                Text(CleanCategory.smartOverview.title)
                                Spacer()
                                if state.totalSelectedBytes > 0 {
                                    Text(state.formattedTotalSelected)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                                        .foregroundColor(.blue)
                                }
                            }
                        } icon: {
                            Image(systemName: CleanCategory.smartOverview.icon)
                                .foregroundColor(CleanCategory.smartOverview.color)
                        }
                    }
                }

                Section("Clean Categories") {
                    ForEach([
                        CleanCategory.systemCache,
                        CleanCategory.browserCache,
                        CleanCategory.appCache,
                        CleanCategory.developerDebris,
                        CleanCategory.logsAndReports,
                        CleanCategory.orphanedApps,
                        CleanCategory.largeAndOldFiles,
                        CleanCategory.trashAndDownloads
                    ]) { category in
                        NavigationLink(value: category) {
                            CategoryRow(category: category, state: state)
                        }
                    }
                }

                Section("Configuration") {
                    NavigationLink(value: CleanCategory.settings) {
                        Label(CleanCategory.settings.title, systemImage: CleanCategory.settings.icon)
                            .foregroundColor(CleanCategory.settings.color)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Mini Disk Gauge at bottom of sidebar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.secondary)
                    Text("Macintosh HD")
                        .font(.caption.bold())
                    Spacer()
                    Text("\(state.storage.formattedFree) Free")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: max(0, min(geo.size.width * CGFloat(state.storage.percentUsed), geo.size.width)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Capacity: \(state.storage.formattedTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if state.storage.reclaimableBytes > 0 {
                        Text("+\(state.storage.formattedReclaimable) junk")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
    }
}

private struct CategoryRow: View {
    let category: CleanCategory
    @ObservedObject var state: AppState

    var body: some View {
        Label {
            HStack {
                Text(category.title)
                Spacer()
                let catBytes = state.reclaimableBytes(for: category)
                if catBytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: catBytes, countStyle: .file))
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(category.color.opacity(0.15)))
                        .foregroundColor(category.color)
                }
            }
        } icon: {
            Image(systemName: category.icon)
                .foregroundColor(category.color)
        }
    }
}
