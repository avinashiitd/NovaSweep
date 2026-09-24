import SwiftUI

public struct LargeFilesView: View {
    @ObservedObject var state: AppState

    let filterTypes = ["All", "DMG/PKG", "ZIP/Archives", "Videos", "Documents"]

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CleanCategory.largeAndOldFiles.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: CleanCategory.largeAndOldFiles.icon)
                        .font(.title2)
                        .foregroundColor(CleanCategory.largeAndOldFiles.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Large & Forgotten Files")
                        .font(.title2.bold())
                    Text("Identify massive files taking up valuable disk storage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Threshold Picker
                HStack(spacing: 8) {
                    Text("Minimum Size:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Threshold", selection: $state.largeFileThresholdMB) {
                        Text("50 MB").tag(50)
                        Text("100 MB").tag(100)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1024)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Filters & Actions
            HStack(spacing: 12) {
                Picker("Filter Type", selection: $state.largeFileFilter) {
                    ForEach(filterTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Spacer()

                Button("Select All") {
                    state.selectAll(for: .largeAndOldFiles)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    state.deselectAll(for: .largeAndOldFiles)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))

            Divider()

            // Large files list
            let items = filteredLargeFiles()
            if state.isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning Large & Old Files...")
                        .font(.headline)
                    Text("Searching Downloads and Media folders for files over \(state.largeFileThresholdMB) MB.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.85))
                    Text(state.hasCompletedInitialScan ? "No Large Files Found" : "Not Scanned Yet")
                        .font(.headline)
                    Text(state.hasCompletedInitialScan ? "No files over \(state.largeFileThresholdMB) MB detected in your Downloads and Media folders." : "Run a Smart Scan from Dashboard to analyze large & forgotten files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { item.isSelected },
                                set: { _ in state.toggleItemSelection(item.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(systemName: fileIcon(for: item.path))
                                .font(.title3)
                                .foregroundColor(CleanCategory.largeAndOldFiles.color)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.body.bold())
                                Text(item.path)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(item.formattedSize)
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundColor(.orange)

                                if item.modifiedDate != nil {
                                    Text(item.formattedDate)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Button {
                                state.revealInFinder(path: item.path)
                            } label: {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                state.revealInFinder(path: item.path)
                            }
                            Button("Open File") {
                                state.openItem(path: item.path)
                            }
                            Button("Add to Whitelist") {
                                state.addToWhitelist(path: item.path)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func filteredLargeFiles() -> [DiskItem] {
        let all = state.items(for: .largeAndOldFiles)
        if state.largeFileFilter == "All" { return all }

        return all.filter { item in
            let path = item.path.lowercased()
            switch state.largeFileFilter {
            case "DMG/PKG":
                return path.hasSuffix(".dmg") || path.hasSuffix(".pkg") || path.hasSuffix(".iso")
            case "ZIP/Archives":
                return path.hasSuffix(".zip") || path.hasSuffix(".tar") || path.hasSuffix(".gz") || path.hasSuffix(".7z")
            case "Videos":
                return path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".mkv") || path.hasSuffix(".avi")
            case "Documents":
                return path.hasSuffix(".pdf") || path.hasSuffix(".docx") || path.hasSuffix(".psd") || path.hasSuffix(".sketch")
            default:
                return true
            }
        }
    }

    private func fileIcon(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "pkg": return "shippingbox.fill"
        case "zip", "tar", "gz", "7z": return "doc.zipper"
        case "mp4", "mov", "mkv": return "film.fill"
        case "pdf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }
}
