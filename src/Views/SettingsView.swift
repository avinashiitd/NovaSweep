import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings & Safety")
                            .font(.title2.bold())
                        Text("Configure safety rails, cleanup behaviors, and folder exclusions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Safety Options Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Safety Rails")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $state.safeModeTrash) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Safe Trash Deletion (Recommended)")
                                    .fontWeight(.semibold)
                                Text("Moves cleaned items to macOS Trash (~/.Trash) so they can be easily restored if needed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: $state.dryRunMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dry Run Simulation Mode")
                                    .fontWeight(.semibold)
                                Text("Simulate scans and cleanup actions without deleting or moving any actual files.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                }

                // Whitelist & Exclusions
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exclusion List (Whitelist)")
                                .font(.headline)
                            Text("Paths and folders in this list will never be scanned or cleaned.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        if !state.whitelist.isEmpty {
                            Button("Clear All") {
                                state.clearWhitelist()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }

                        Button {
                            pickFolderForWhitelist()
                        } label: {
                            Label("Add Folder", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if state.whitelist.isEmpty {
                        HStack {
                            Spacer()
                            Text("No folders currently excluded.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(state.whitelist).sorted(), id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(path)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        state.removeFromWhitelist(path: path)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    }
                }

                // Disclaimer & Safety Notice
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Important Disclaimer")
                            .font(.headline)
                    }

                    Text("NovaSweep is designed to identify and safely reclaim non-productive disk usage (caches, logs, developer artifacts, and old downloads). By default, Safe Trash Mode is active so items can be restored from ~/.Trash. However, disk cleanup operations affect local files. Always review items before cleaning, use Dry Run Mode to simulate results, and maintain regular backups using Time Machine. NovaSweep is provided 'as is' without warranty of any kind.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))

                // About Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("About NovaSweep")
                        .font(.headline)

                    HStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("NovaSweep for macOS")
                                .font(.headline)
                            Text("Version 1.0 (Apple Silicon Native)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Private, fast, and transparent disk space retriever for MacBooks and iMacs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                }
            }
            .padding(24)
        }
    }

    private func pickFolderForWhitelist() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Exclude"
        if panel.runModal() == .OK, let url = panel.url {
            state.addToWhitelist(path: url.path)
        }
    }
}
