import SwiftUI

struct PortRowView: View {
    let entry: PortEntry
    let isFavorite: Bool
    var showPath: Bool = true
    let onKill: () -> Void
    let onOpenBrowser: () -> Void
    let onRestart: () -> Void
    let onToggleFavorite: () -> Void
    let onOpenInWarp: () -> Void
    @State private var isKilling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Text(":\(String(entry.port))")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Circle()
                        .fill(isKilling ? .yellow : .green)
                        .frame(width: 6, height: 6)

                    Text(entry.processName)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 6) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)

                    Button(action: onOpenInWarp) {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isKilling)

                    Button(action: onOpenBrowser) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isKilling)

                    Button {
                        isKilling = true
                        onRestart()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            isKilling = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isKilling)

                    Button {
                        isKilling = true
                        onKill()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            isKilling = false
                        }
                    } label: {
                        if isKilling {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isKilling)
                }
            }

            if showPath && entry.displayPath.contains("/") {
                Text(entry.displayPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isKilling ? 0.5 : 1)
    }
}
