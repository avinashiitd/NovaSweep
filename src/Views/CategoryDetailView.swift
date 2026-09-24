import SwiftUI
import AppKit

public struct CategoryDetailView: View {
    let category: CleanCategory
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(category.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.title2.bold())
                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    let totalCat = state.reclaimableBytes(for: category)
                    Text(ByteCountFormatter.string(fromByteCount: totalCat, countStyle: .file))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(totalCat > 0 ? category.color : .secondary)
                    Text("Selected to Clean")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Control Bar: Search and Selection Buttons
            HStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter by name or path...", text: $state.searchText)
                        .textFieldStyle(.plain)
                    if !state.searchText.isEmpty {
                        Button {
                            state.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                .frame(maxWidth: 280)

                Spacer()

                Button("Select All") {
                    state.selectAll(for: category)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    state.deselectAll(for: category)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Recommended") {
                    state.selectSafeOnly(for: category)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))

            Divider()

            // Items List
            let items = state.filteredItems(for: category)
            if state.isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning \(category.title)...")
                        .font(.headline)
                    Text("Auditing files and computing potential space savings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.85))
                    Text(state.hasCompletedInitialScan ? "All Clean!" : "No items detected")
                        .font(.headline)
                    Text(state.hasCompletedInitialScan ? "No reclaimable clutter was found in \(category.title)." : "Run a Smart Scan from Dashboard to analyze this area.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        ItemRowView(item: item, state: state)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

private struct ItemRowView: View {
    let item: DiskItem
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in state.toggleItemSelection(item.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.body.bold())

                    Text(item.subCategory)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundColor(.secondary)

                    if !item.isSafe {
                        Text("REVIEW NEEDED")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                    }
                }

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.path)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.formattedSize)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundColor(item.size > 500_000_000 ? .orange : .primary)

                if item.modifiedDate != nil {
                    Text(item.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Quick Actions Menu
            Menu {
                Button {
                    state.revealInFinder(path: item.path)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button {
                    state.addToWhitelist(path: item.path)
                } label: {
                    Label("Ignore / Whitelist", systemImage: "eye.slash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Reveal in Finder") {
                state.revealInFinder(path: item.path)
            }
            Button("Add to Whitelist") {
                state.addToWhitelist(path: item.path)
            }
        }
    }
}
