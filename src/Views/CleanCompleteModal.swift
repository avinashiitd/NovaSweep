import SwiftUI

public struct CleanCompleteModal: View {
    let summary: CleanSummary?
    let isDryRun: Bool
    let onDismiss: () -> Void

    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isDryRun ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: isDryRun ? "eye.fill" : "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isDryRun ? .orange : .green)
            }

            VStack(spacing: 6) {
                Text(isDryRun ? "Dry Run Complete!" : "Disk Cleanup Complete!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(isDryRun ? "The following space can be safely retrieved:" : "Successfully retrieved disk space:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(summary?.formattedBytesFreed ?? "0 B")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(isDryRun ? .orange : .green)
            }

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(summary?.itemsCleaned ?? 0)")
                        .font(.title3.bold())
                    Text("Items Processed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text(isDryRun ? "Simulated" : "Freed")
                        .font(.title3.bold())
                    Text("Action Type")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))

            if let errors = summary?.errors, !errors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Warnings / Notices (\(errors.count)):")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(errors, id: \.self) { err in
                                Text("• \(err)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 90)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
            }

            Button {
                onDismiss()
            } label: {
                Text("Back to Dashboard")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
        }
        .padding(28)
        .frame(minWidth: 440, idealWidth: 460, minHeight: 380)
    }
}
