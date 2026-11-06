import SwiftUI

/// Modal sheet for interactive human-in-the-loop review of receipt items, tax, and tip parsed via OCR.
///
/// Follows ADR-002: operates on `ParsedReceiptReviewDraft` to validate and edit items before importing them
/// into the live receipt session, protecting financial domain invariants.
struct ReceiptParsedReviewSheet: View {

    // MARK: - Bindings & Environment

    @Bindable var viewModel: ReceiptEditorViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local State

    @State private var replaceExistingItems: Bool = false
    @State private var quickParticipantName: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if let draft = viewModel.parsedReviewDraft {
                reviewContent(draft: draft)
            } else {
                emptyReviewContent
            }
        }
    }

    // MARK: - Review Content

    @ViewBuilder
    private func reviewContent(draft: ParsedReceiptReviewDraft) -> some View {
        Form {
            // 1. Reconciliation Diagnostic Card
            Section {
                reconciliationCard(diagnostic: draft.reconciliation, draft: draft)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
            }

            // 2. Error Banner (if validation failed on import attempt)
            if let errorMsg = viewModel.importValidationErrorMessage {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.title3)
                            .foregroundStyle(.red)

                        Text(errorMsg)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 3. Quick Diner Registration (Mandatory if participants are empty)
            if viewModel.participants.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title3)
                                .foregroundStyle(.orange)

                            Text("Agrega al menos un comensal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Text("Para importar y dividir la cuenta se requiere al menos un participante registrado.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("Nombre (ej. Juan, Ana)", text: $quickParticipantName)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                                .onSubmit { addQuickParticipant() }

                            Button("Agregar") {
                                addQuickParticipant()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(quickParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .frame(minHeight: 44)
                        }

                        if let validation = viewModel.validationMessage {
                            Text(validation)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Comensales Requeridos")
                }
            } else {
                Section {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("\(viewModel.participants.count) comensales registrados:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(viewModel.participants.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            }

            // 4. Suggested Merchant Title
            if !draft.merchantName.isEmpty || viewModel.receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Comercio / Título Sugerido") {
                    TextField("Nombre del establecimiento", text: Binding(
                        get: { draft.merchantName },
                        set: { draft.merchantName = $0 }
                    ))
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
            }

            // 5. Detected Dishes List
            Section {
                ForEach(draft.items) { itemDraft in
                    ParsedItemReviewRowView(
                        itemDraft: itemDraft,
                        currency: draft.currency,
                        onDelete: {
                            draft.removeItem(id: itemDraft.id)
                        }
                    )
                }
                .onDelete { offsets in
                    let itemsToDelete = offsets.map { draft.items[$0] }
                    for item in itemsToDelete {
                        draft.removeItem(id: item.id)
                    }
                }

                Button {
                    draft.addItem()
                } label: {
                    Label("Agregar platillo manual", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            } header: {
                let includedCount = draft.items.filter(\.isIncluded).count
                Text("Platillos Detectados (\(includedCount) de \(draft.items.count) seleccionados)")
            }

            // 6. Tax & Tip Controls
            Section("Impuestos y Propina") {
                Toggle(isOn: Binding(
                    get: { draft.includeDetectedTax },
                    set: { draft.includeDetectedTax = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Impuesto / IVA detectado")
                            .font(.subheadline.weight(.medium))
                        if let tax = draft.resolvedTax, draft.includeDetectedTax {
                            Text(MoneyFormatter.string(from: tax))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !draft.taxText.isEmpty {
                            Text("Monto: \(draft.taxText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No detectado en el ticket")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if draft.includeDetectedTax {
                    HStack {
                        Text("Monto IVA")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(draft.currency.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: Binding(
                            get: { draft.taxText },
                            set: { draft.taxText = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    }
                }

                Toggle(isOn: Binding(
                    get: { draft.includeDetectedTip },
                    set: { draft.includeDetectedTip = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Propina sugerida detectada")
                            .font(.subheadline.weight(.medium))
                        if let tip = draft.resolvedTip, draft.includeDetectedTip {
                            Text(MoneyFormatter.string(from: tip))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !draft.tipText.isEmpty {
                            Text("Monto: \(draft.tipText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No detectada en el ticket")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if draft.includeDetectedTip {
                    HStack {
                        Text("Monto Propina")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(draft.currency.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: Binding(
                            get: { draft.tipText },
                            set: { draft.tipText = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // 7. Import Mode (if items already exist in session)
            if !viewModel.items.isEmpty {
                Section {
                    Picker("Modo de importación", selection: $replaceExistingItems) {
                        Text("Sumar a los \(viewModel.items.count) actuales").tag(false)
                        Text("Reemplazar artículos actuales").tag(true)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Modo de Importación")
                } footer: {
                    if replaceExistingItems {
                        Text("Se eliminarán los \(viewModel.items.count) artículos actuales y se reemplazarán con los platillos seleccionados.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Los platillos seleccionados se sumarán a la lista de artículos registrados.")
                    }
                }
            }
        }
        .navigationTitle("Revisar Recibo Detectado")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    viewModel.dismissParsedReceiptReview()
                    dismiss()
                }
                .frame(minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                let count = draft.items.filter(\.isIncluded).count
                Button("Importar (\(count))") {
                    confirmImport()
                }
                .fontWeight(.bold)
                .frame(minHeight: 44)
                .disabled(count == 0 || viewModel.participants.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar(draft: draft)
        }
    }

    // MARK: - Bottom Action Bar

    private func bottomActionBar(draft: ParsedReceiptReviewDraft) -> some View {
        let count = draft.items.filter(\.isIncluded).count
        return VStack(spacing: 8) {
            Button {
                confirmImport()
            } label: {
                Label(
                    "Importar \(count) \(count == 1 ? "platillo" : "platillos")",
                    systemImage: "arrow.down.doc.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(count == 0 || viewModel.participants.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Reconciliation Diagnostic Card

    private func reconciliationCard(diagnostic: ReceiptReconciliationDiagnostic, draft: ParsedReceiptReviewDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                statusIcon(for: diagnostic.status)
                    .font(.title2)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle(for: diagnostic.status))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(statusDescription(for: diagnostic.status))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtotal Seleccionado")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(MoneyFormatter.string(from: diagnostic.computedItemsSubtotal))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                Spacer()

                if let detSub = diagnostic.detectedSubtotal {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subtotal Ticket")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(MoneyFormatter.string(from: detSub))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                    }
                    Spacer()
                }

                if let detTot = diagnostic.detectedTotal {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total Ticket")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(MoneyFormatter.string(from: detTot))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(diagnostic.status == .verified ? Color.green : Color.primary)
                    }
                }
            }
        }
        .padding(14)
        .background(statusBackgroundColor(for: diagnostic.status), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusBorderColor(for: diagnostic.status), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusIcon(for status: ReceiptReconciliationStatus) -> some View {
        switch status {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .discrepancy:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .partial:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        case .empty:
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
        }
    }

    private func statusTitle(for status: ReceiptReconciliationStatus) -> String {
        switch status {
        case .verified:
            return "Totales verificados"
        case .discrepancy:
            return "Discrepancia detectada"
        case .partial:
            return "Verificación parcial"
        case .empty:
            return "Sin platillos seleccionados"
        }
    }

    private func statusDescription(for status: ReceiptReconciliationStatus) -> String {
        switch status {
        case .verified:
            return "La suma de platillos e impuestos coincide con el total detectado."
        case .discrepancy(let diff, let currency):
            let formattedDiff = MoneyFormatter.string(from: Money(amountInMinorUnits: abs(diff), currency: currency))
            let relation = diff > 0 ? "faltan" : "sobran"
            return "Discrepancia detectada por \(formattedDiff) (\(relation) respecto al ticket) — Revisa cantidades o precios antes de importar."
        case .partial:
            return "El ticket no incluye línea de total — Revisa los montos antes de importar."
        case .empty:
            return "Selecciona al menos un platillo de la lista para calcular los totales."
        }
    }

    private func statusBackgroundColor(for status: ReceiptReconciliationStatus) -> Color {
        switch status {
        case .verified:
            return Color.green.opacity(0.08)
        case .discrepancy:
            return Color.orange.opacity(0.08)
        case .partial:
            return Color.blue.opacity(0.08)
        case .empty:
            return Color.secondary.opacity(0.08)
        }
    }

    private func statusBorderColor(for status: ReceiptReconciliationStatus) -> Color {
        switch status {
        case .verified:
            return Color.green.opacity(0.3)
        case .discrepancy:
            return Color.orange.opacity(0.3)
        case .partial:
            return Color.blue.opacity(0.3)
        case .empty:
            return Color.secondary.opacity(0.2)
        }
    }

    // MARK: - Actions

    private func addQuickParticipant() {
        let trimmed = quickParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.newParticipantName = trimmed
        viewModel.addParticipant()
        if viewModel.validationMessage == nil {
            quickParticipantName = ""
        }
    }

    private func confirmImport() {
        let success = viewModel.confirmParsedReceiptImport(replaceExistingItems: replaceExistingItems)
        if success {
            dismiss()
        }
    }

    private var emptyReviewContent: some View {
        ContentUnavailableView {
            Label("Sin Datos de Revisión", systemImage: "sparkles")
        } description: {
            Text("No se encontró ningún candidato de recibo pendiente de revisión.")
        } actions: {
            Button("Cerrar") {
                viewModel.dismissParsedReceiptReview()
                dismiss()
            }
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Individual Dish Row View

struct ParsedItemReviewRowView: View {
    @Bindable var itemDraft: EditableParsedItemDraft
    let currency: Currency
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Checkbox toggle (44x44 pt minimum tap target)
                Button {
                    itemDraft.isIncluded.toggle()
                } label: {
                    Image(systemName: itemDraft.isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(itemDraft.isIncluded ? Color.accentColor : Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(itemDraft.isIncluded ? "Desmarcar \(itemDraft.name)" : "Incluir \(itemDraft.name)")

                // Dish name field
                TextField("Nombre del platillo", text: $itemDraft.name)
                    .font(.body.weight(.medium))
                    .textInputAutocapitalization(.words)
                    .disabled(!itemDraft.isIncluded)

                Spacer()

                // Dynamically calculated line total
                if let lineTotal = itemDraft.lineTotal(currency: currency) {
                    Text(MoneyFormatter.string(from: lineTotal, includeCurrencyCode: false))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(itemDraft.isIncluded ? .primary : .secondary)
                }
            }

            HStack(spacing: 12) {
                // Quantity Stepper controls with 44x44 pt touch targets
                HStack(spacing: 2) {
                    Button {
                        if itemDraft.quantity > 1 {
                            itemDraft.quantity -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(itemDraft.quantity > 1 && itemDraft.isIncluded ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(itemDraft.quantity <= 1 || !itemDraft.isIncluded)
                    .accessibilityLabel("Disminuir cantidad de \(itemDraft.name)")

                    Text("\(itemDraft.quantity)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 24, alignment: .center)
                        .accessibilityLabel("Cantidad: \(itemDraft.quantity)")

                    Button {
                        itemDraft.quantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(itemDraft.isIncluded ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!itemDraft.isIncluded)
                    .accessibilityLabel("Aumentar cantidad de \(itemDraft.name)")
                }

                // Unit Price with currency prefix
                HStack(spacing: 4) {
                    Text("× \(currency.symbol)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    TextField("0.00", text: $itemDraft.unitPriceText)
                        .keyboardType(.decimalPad)
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(!itemDraft.isIncluded)
                        .accessibilityLabel("Precio unitario de \(itemDraft.name)")
                }

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eliminar \(itemDraft.name)")
            }

            // OCR Source snippet
            if !itemDraft.sourceLineText.isEmpty && itemDraft.sourceLineText != "Manual" {
                Text("OCR: \"\(itemDraft.sourceLineText)\"")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 4)
        .opacity(itemDraft.isIncluded ? 1.0 : 0.45)
    }
}
