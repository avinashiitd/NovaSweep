import SwiftUI

public struct DashboardView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Hero Banner Card
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                Text("NovaSweep")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                            }
                            Text("Next-Gen Intelligent Disk Space Optimizer for Mac")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        // Mode Badges
                        HStack(spacing: 8) {
                            if state.dryRunMode {
                                Text("DRY RUN MODE")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                                    .foregroundColor(.orange)
                            }
                            if state.safeModeTrash {
                                Text("SAFE TRASH ON")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.green.opacity(0.2)))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Divider()

                    // Storage Metrics Row
                    HStack(spacing: 20) {
                        MetricCard(
                            title: "Disk Capacity",
                            value: state.storage.formattedTotal,
                            icon: "internaldrive",
                            color: .blue
                        )
                        MetricCard(
                            title: "Free Space",
                            value: state.storage.formattedFree,
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        MetricCard(
                            title: "Used Space",
                            value: state.storage.formattedUsed,
                            icon: "chart.pie.fill",
                            color: .secondary
                        )
                        MetricCard(
                            title: "Junk Detected",
                            value: state.totalSelectedBytes > 0 ? state.formattedTotalSelected : "0 B",
                            icon: "trash.circle.fill",
                            color: state.totalSelectedBytes > 0 ? .orange : .secondary,
                            highlight: state.totalSelectedBytes > 0
                        )
                    }

                    // Storage Progress Bar
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 14)

                                // Used portion
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(geo.size.width * CGFloat(state.storage.percentUsed), geo.size.width)), height: 14)

                                // Reclaimable highlighted overlay at the end of used portion
                                if state.storage.percentReclaimable > 0 {
                                    let reclaimWidth = max(0, min(geo.size.width * CGFloat(state.storage.percentReclaimable), geo.size.width))
                                    let offset = max(0, geo.size.width * CGFloat(state.storage.percentUsed) - reclaimWidth)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange)
                                        .frame(width: reclaimWidth, height: 14)
                                        .offset(x: offset)
                                }
                            }
                        }
                        .frame(height: 14)

                        HStack {
                            Text("System & Data: \(state.storage.formattedUsed)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            if state.storage.reclaimableBytes > 0 {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                                    Text("Reclaimable: \(state.storage.formattedReclaimable)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }

                    // Primary Action Buttons
                    HStack(spacing: 16) {
                        if state.isScanning {
                            Button {
                                state.cancelScan()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cancel Scan")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.large)
                        } else {
                            Button {
                                state.startSmartScan()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(state.hasCompletedInitialScan ? "Smart Scan Again" : "Smart Scan Now")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.large)
                            .disabled(state.isCleaning)
                        }

                        Button {
                            state.showConfirmationAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                if state.isCleaning {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(state.isCleaning ? "Cleaning..." : (state.totalSelectedBytes > 0 ? "Clean Selected (\(state.formattedTotalSelected))" : "Clean Selected"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(state.totalSelectedBytes > 0 ? .orange : .gray)
                        .controlSize(.large)
                        .disabled(state.totalSelectedBytes == 0 || state.isScanning || state.isCleaning)
                    }

                    // Real-time Status Banner
                    HStack {
                        Image(systemName: state.isScanning ? "magnifyingglass" : (state.isCleaning ? "trash" : "info.circle"))
                            .foregroundColor(.secondary)
                        Text(state.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if state.isScanning {
                            ProgressView(value: state.scanProgress)
                                .frame(width: 140)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                )

                // MARK: - Category Grid Cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optimization Breakdown")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
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
                            CategoryDashboardCard(category: cat, state: state)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(highlight ? .orange : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

private struct CategoryDashboardCard: View {
    let category: CleanCategory
    @ObservedObject var state: AppState

    var body: some View {
        Button {
            state.selectedCategory = category
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(category.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(category.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    let bytes = state.totalBytes(for: category)
                    Text(bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : "0 B")
                        .font(.subheadline.bold())
                        .foregroundColor(bytes > 0 ? category.color : .secondary)

                    let count = state.items(for: category).count
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
