import SwiftUI
import UIKit

/// Modal sheet for inspecting, copying, and interacting with raw OCR text detected from the receipt image.
struct ReceiptOCRTextSheet: View {

    // MARK: - Bindings & Local State

    @Bindable var viewModel: ReceiptEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSummaryBanner

                if shouldShowQuickAction {
                    quickActionBanner
                }

                Divider()

                mainContent
            }
            .navigationTitle("Texto del Recibo (OCR)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo") {
                        dismiss()
                    }
                    .frame(minHeight: 44)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.hasOCRText {
                        Button {
                            copyTextToClipboard()
                        } label: {
                            if showCopiedConfirmation {
                                Label("¡Copiado!", systemImage: "checkmark")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Copiar", systemImage: "doc.on.doc")
                            }
                        }
                        .frame(minHeight: 44)
                        .disabled(showCopiedConfirmation)
                        .accessibilityLabel(
                            showCopiedConfirmation
                                ? "Texto copiado al portapapeles"
                                : "Copiar todo el texto al portapapeles"
                        )
                    }

                    Button {
                        Task {
                            await viewModel.recognizeReceiptText()
                        }
                    } label: {
                        Label("Reescanear", systemImage: "arrow.clockwise")
                    }
                    .frame(minHeight: 44)
                    .disabled(viewModel.isRecognizingText || !viewModel.hasReceiptImage)
                    .accessibilityLabel("Volver a escanear el ticket con OCR")
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSummaryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.ocrLineCount) \(viewModel.ocrLineCount == 1 ? "línea detectada" : "líneas detectadas")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let result = viewModel.lastOCRResult, result.averageConfidence > 0 {
                    let confidencePct = Int(result.averageConfidence * 100)
                    Text("Confianza promedio: \(confidencePct)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Texto extraído con Apple Vision")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var shouldShowQuickAction: Bool {
        viewModel.receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.hasOCRText
    }

    private var quickActionBanner: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.applySuggestedTitleFromOCR()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usar sugerencia como título de la cuenta")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if let suggested = suggestedTitleSnippet {
                            Text("\"\(suggested)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityLabel("Usar sugerencia de OCR como título de la cuenta: \(suggestedTitleSnippet ?? "")")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isRecognizingText {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Reconociendo texto del ticket...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reconociendo texto del ticket en progreso")
        } else if let rawText = viewModel.ocrRawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linesScrollView
        } else {
            emptyStateView
        }
    }

    private var linesScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(displayLines.indices, id: \.self) { index in
                    let line = displayLines[index]
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28, alignment: .trailing)
                            .accessibilityHidden(true)

                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.02) : Color.clear)
                }
            }
            .padding(.vertical, 8)
        }
        .textSelection(.enabled)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Sin Texto Detectado", systemImage: "text.viewfinder")
        } description: {
            Text("No se encontró texto en este ticket o la imagen aún no ha sido analizada.")
        } actions: {
            if viewModel.hasReceiptImage {
                Button {
                    Task {
                        await viewModel.recognizeReceiptText()
                    }
                } label: {
                    Label("Escanear Ticket", systemImage: "text.viewfinder")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helpers

    private var displayLines: [String] {
        if let result = viewModel.lastOCRResult, !result.lines.isEmpty {
            return result.lines.map(\.text)
        } else if let raw = viewModel.ocrRawText {
            return raw.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return []
    }

    private var suggestedTitleSnippet: String? {
        if let firstLine = viewModel.lastOCRResult?.lines.first?.text {
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let firstRaw = viewModel.ocrRawText?.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return firstRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private var headerAccessibilityLabel: String {
        let lineWord = viewModel.ocrLineCount == 1 ? "línea detectada" : "líneas detectadas"
        var parts: [String] = ["\(viewModel.ocrLineCount) \(lineWord)"]
        if let result = viewModel.lastOCRResult, result.averageConfidence > 0 {
            parts.append("\(Int(result.averageConfidence * 100)) por ciento de confianza promedio")
        }
        return parts.joined(separator: ", ")
    }

    private func copyTextToClipboard() {
        guard let raw = viewModel.ocrRawText, !raw.isEmpty else { return }
        UIPasteboard.general.string = raw
        showCopiedConfirmation = true
        AccessibilityNotification.Announcement("Texto copiado al portapapeles").post()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showCopiedConfirmation = false
        }
    }
}

// MARK: - Previews

#Preview("With OCR Lines") {
    let vm = ReceiptEditorViewModel()
    vm.attachSampleReceipt(.taqueriaElPastor)
    return ReceiptOCRTextSheet(viewModel: vm)
        .task {
            await vm.recognizeReceiptText()
        }
}

#Preview("Empty OCR") {
    let vm = ReceiptEditorViewModel()
    return ReceiptOCRTextSheet(viewModel: vm)
}
