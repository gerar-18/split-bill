import SwiftUI

/// Modal sheet for creating and editing a receipt line item across all 4 split modes:
/// Individual (.wholeItem), Partes Iguales (.equal), Porcentaje (.percentage), and Porciones (.portion).
struct ReceiptItemEditorSheet: View {

    // MARK: - Bindings

    @Bindable var viewModel: ReceiptEditorViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let draft = Binding($viewModel.activeItemDraft) {
                    formContent(draft: draft)
                } else {
                    ContentUnavailableView(
                        "Sin borrador activo",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Selecciona o agrega un artículo para editarlo.")
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) {
                        viewModel.validationMessage = nil
                        viewModel.activeItemDraft = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        viewModel.saveActiveDraft()
                    }
                    .fontWeight(.bold)
                    .disabled(!isSaveEnabled)
                }
            }
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(draft: Binding<ReceiptItemDraft>) -> some View {
        Form {
            // Inline Validation Warning Banner
            if let message = viewModel.validationMessage {
                Section {
                    validationBanner(message: message)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Section 1: Item Details
            itemDetailsSection(draft: draft)

            // Section 2: Split Mode Selection
            splitModeSection(draft: draft)

            // Section 3: Participant Assignment
            assignmentSection(draft: draft)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft.splitModeKind.wrappedValue) { _, newKind in
            synchronizeDraftDefaults(draft: draft, for: newKind)
        }
        .onAppear {
            synchronizeInitialDefaults(draft: draft)
        }
    }

    // MARK: - Sections

    private func itemDetailsSection(draft: Binding<ReceiptItemDraft>) -> some View {
        Section("Detalles del Artículo") {
            TextField("Nombre (ej. Tacos al pastor)", text: draft.name)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)

            HStack {
                Text("Precio Unitario")
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Text("$")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    TextField("0.00", text: draft.unitPriceText)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                        .accessibilityLabel("Precio unitario del artículo")
                }
            }

            Stepper("Cantidad: \(draft.quantity.wrappedValue)", value: draft.quantity, in: 1...99)
                .monospacedDigit()
        }
    }

    private func splitModeSection(draft: Binding<ReceiptItemDraft>) -> some View {
        Section("Modo de División") {
            Picker("Modo", selection: draft.splitModeKind) {
                ForEach(SplitModeKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func assignmentSection(draft: Binding<ReceiptItemDraft>) -> some View {
        Section("Asignación de Comensales") {
            switch draft.splitModeKind.wrappedValue {
            case .wholeItem:
                wholeItemAssignmentView(draft: draft)
            case .equal:
                equalAssignmentView(draft: draft)
            case .percentage:
                percentageAssignmentView(draft: draft)
            case .portion:
                portionAssignmentView(draft: draft)
            }
        }
    }

    // MARK: - Split Mode Specific Subviews

    @ViewBuilder
    private func wholeItemAssignmentView(draft: Binding<ReceiptItemDraft>) -> some View {
        if viewModel.participants.isEmpty {
            Text("No hay comensales registrados.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Asignar a", selection: draft.selectedParticipantID) {
                ForEach(viewModel.participants) { participant in
                    Text(participant.name).tag(Optional(participant.id))
                }
            }
        }
    }

    @ViewBuilder
    private func equalAssignmentView(draft: Binding<ReceiptItemDraft>) -> some View {
        if viewModel.participants.isEmpty {
            Text("No hay comensales registrados.")
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Button("Seleccionar todos") {
                    draft.equalParticipantIDs.wrappedValue = Set(viewModel.participants.map(\.id))
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.medium))

                Spacer()

                Button("Deseleccionar todos") {
                    draft.equalParticipantIDs.wrappedValue = []
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.medium))
            }
            .padding(.vertical, 2)

            ForEach(viewModel.participants) { participant in
                let isSelected = draft.equalParticipantIDs.wrappedValue.contains(participant.id)
                Button {
                    if isSelected {
                        draft.equalParticipantIDs.wrappedValue.remove(participant.id)
                    } else {
                        draft.equalParticipantIDs.wrappedValue.insert(participant.id)
                    }
                } label: {
                    HStack {
                        Text(participant.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .font(.title3)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("\(participant.name), \(isSelected ? "seleccionado" : "no seleccionado")")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    @ViewBuilder
    private func percentageAssignmentView(draft: Binding<ReceiptItemDraft>) -> some View {
        if viewModel.participants.isEmpty {
            Text("No hay comensales registrados.")
                .foregroundStyle(.secondary)
        } else {
            let total = draft.percentages.wrappedValue.values.reduce(0, +)
            let isComplete = (total == 100)

            HStack {
                Text("Total Asignado")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(total)% de 100%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isComplete ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (isComplete ? Color.green : Color.orange).opacity(0.15),
                        in: .capsule
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total asignado: \(total) por ciento de 100 por ciento. \(isComplete ? "Completo" : "Incompleto")")

            ForEach(viewModel.participants) { participant in
                let currentPct = draft.percentages.wrappedValue[participant.id, default: 0]
                HStack {
                    Text(participant.name)
                        .font(.body)
                        .accessibilityHidden(true)

                    Spacer()

                    Stepper(
                        "\(currentPct)%",
                        value: Binding(
                            get: { draft.percentages.wrappedValue[participant.id, default: 0] },
                            set: { draft.percentages.wrappedValue[participant.id] = max(0, min(100, $0)) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .monospacedDigit()
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(participant.name): \(currentPct) por ciento")
                }
            }

            Button("Distribuir equitativamente") {
                distributePercentageEqually(draft: draft)
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
    }

    @ViewBuilder
    private func portionAssignmentView(draft: Binding<ReceiptItemDraft>) -> some View {
        if viewModel.participants.isEmpty {
            Text("No hay comensales registrados.")
                .foregroundStyle(.secondary)
        } else {
            let totalPortions = draft.portions.wrappedValue.values.reduce(0, +)

            HStack {
                Text("Total de Partes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(totalPortions)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15), in: .capsule)
            }
            .accessibilityElement(children: .combine)

            ForEach(viewModel.participants) { participant in
                let shares = draft.portions.wrappedValue[participant.id, default: 0]
                let pct = totalPortions > 0 ? (shares * 100 + totalPortions / 2) / totalPortions : 0

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.name)
                            .font(.body)

                        Text(portionDescription(shares: shares, percentage: pct))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)

                    Spacer()

                    Stepper(
                        "\(shares)",
                        value: Binding(
                            get: { draft.portions.wrappedValue[participant.id, default: 0] },
                            set: { draft.portions.wrappedValue[participant.id] = max(0, min(20, $0)) }
                        ),
                        in: 0...20
                    )
                    .monospacedDigit()
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(participant.name): \(shares) partes, \(pct) por ciento")
                }
            }

            Button("1 parte para todos") {
                var newPortions: [Participant.ID: Int] = [:]
                for p in viewModel.participants {
                    newPortions[p.id] = 1
                }
                draft.portions.wrappedValue = newPortions
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
    }

    private func validationBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions & Helpers

    private var navigationTitle: String {
        guard let draft = viewModel.activeItemDraft else { return "Artículo" }
        let isEditing = viewModel.items.contains(where: { $0.id == draft.id })
        return isEditing ? "Editar Artículo" : "Nuevo Artículo"
    }

    private var isSaveEnabled: Bool {
        guard let draft = viewModel.activeItemDraft else { return false }
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let minorUnits = MoneyFormatter.parseMinorUnits(from: draft.unitPriceText, currency: viewModel.currency),
              minorUnits >= 0 else {
            return false
        }
        return true
    }

    private func synchronizeInitialDefaults(draft: Binding<ReceiptItemDraft>) {
        if draft.selectedParticipantID.wrappedValue == nil {
            draft.selectedParticipantID.wrappedValue = viewModel.participants.first?.id
        }
        if draft.equalParticipantIDs.wrappedValue.isEmpty && !viewModel.participants.isEmpty {
            draft.equalParticipantIDs.wrappedValue = Set(viewModel.participants.map(\.id))
        }
    }

    private func synchronizeDraftDefaults(draft: Binding<ReceiptItemDraft>, for kind: SplitModeKind) {
        switch kind {
        case .wholeItem:
            if draft.selectedParticipantID.wrappedValue == nil {
                draft.selectedParticipantID.wrappedValue = viewModel.participants.first?.id
            }
        case .equal:
            if draft.equalParticipantIDs.wrappedValue.isEmpty && !viewModel.participants.isEmpty {
                draft.equalParticipantIDs.wrappedValue = Set(viewModel.participants.map(\.id))
            }
        case .percentage:
            let sum = draft.percentages.wrappedValue.values.reduce(0, +)
            if sum == 0 && !viewModel.participants.isEmpty {
                distributePercentageEqually(draft: draft)
            }
        case .portion:
            let sum = draft.portions.wrappedValue.values.reduce(0, +)
            if sum == 0 && !viewModel.participants.isEmpty {
                var newPortions: [Participant.ID: Int] = [:]
                for p in viewModel.participants {
                    newPortions[p.id] = 1
                }
                draft.portions.wrappedValue = newPortions
            }
        }
    }

    private func distributePercentageEqually(draft: Binding<ReceiptItemDraft>) {
        let participants = viewModel.participants
        guard !participants.isEmpty else { return }
        let count = participants.count
        let base = 100 / count
        let remainder = 100 % count

        var newPercentages: [Participant.ID: Int] = [:]
        for (index, p) in participants.enumerated() {
            newPercentages[p.id] = base + (index < remainder ? 1 : 0)
        }
        draft.percentages.wrappedValue = newPercentages
    }

    private func portionDescription(shares: Int, percentage: Int) -> String {
        if shares == 0 {
            return "0 partes (0%)"
        } else if shares == 1 {
            return "1 parte (\(percentage)%)"
        } else {
            return "\(shares) partes (\(percentage)%)"
        }
    }
}

// MARK: - Previews

#Preview("New Item Draft - Equal Split") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()
    vm.openNewItemDraft()

    return ReceiptItemEditorSheet(viewModel: vm)
}

#Preview("Edit Item Draft - Percentage Split") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()

    if let p1 = vm.participants.first, let p2 = vm.participants.last {
        if let item = try? ReceiptItem(
            name: "Botella de Vino",
            unitPrice: Money(amountInMinorUnits: 65000, currency: .mxn),
            quantity: 1,
            splitMode: .percentage([p1.id: 50, p2.id: 50])
        ) {
            vm.openEditItemDraft(item)
        }
    }

    return ReceiptItemEditorSheet(viewModel: vm)
}

#Preview("Edit Item Draft - Portion Split") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()

    if let p1 = vm.participants.first, let p2 = vm.participants.last {
        if let item = try? ReceiptItem(
            name: "Parrillada",
            unitPrice: Money(amountInMinorUnits: 45000, currency: .mxn),
            quantity: 1,
            splitMode: .portion([p1.id: 2, p2.id: 1])
        ) {
            vm.openEditItemDraft(item)
        }
    }

    return ReceiptItemEditorSheet(viewModel: vm)
}

#Preview("Validation Banner Error") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.openNewItemDraft()
    vm.validationMessage = "Los porcentajes deben sumar exactamente 100% (actual: 80%)."

    return ReceiptItemEditorSheet(viewModel: vm)
}
