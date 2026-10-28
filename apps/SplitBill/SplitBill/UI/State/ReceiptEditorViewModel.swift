import Foundation
import Observation
import SwiftUI

/// The primary `@MainActor` presentation state model for creating, editing, and splitting a receipt.
///
/// Follows ADR-002 by maintaining strict separation: delegates all business rules and financial
/// calculations to the pure `Domain` layer (`Receipt`, `SplitEngine`, `Money`).
@Observable
@MainActor
final class ReceiptEditorViewModel {

    // MARK: - State Properties

    var currency: Currency = .mxn
    var participants: [Participant] = []
    var newParticipantName: String = ""
    var items: [ReceiptItem] = []
    var taxText: String = ""
    var tipSelection: TipSelection = .percentage(10)
    var customTipText: String = ""
    var activeItemDraft: ReceiptItemDraft? = nil
    var validationMessage: String? = nil

    // MARK: - Initializer

    init(currency: Currency = .mxn) {
        self.currency = currency
    }

    // MARK: - Computed Financial Properties

    /// The sum of all line item totals before tax and tip.
    var itemsSubtotal: Money {
        let sum = items.reduce(Int64(0)) { $0 + $1.lineTotal.amountInMinorUnits }
        return Money(amountInMinorUnits: sum, currency: currency)
    }

    /// The tax amount parsed from `taxText` (defaults to zero if empty or invalid).
    var resolvedTax: Money {
        let parsed = MoneyFormatter.parseMinorUnits(from: taxText, currency: currency) ?? 0
        return Money(amountInMinorUnits: max(0, parsed), currency: currency)
    }

    /// The tip amount resolved from the active `tipSelection` and items subtotal.
    var resolvedTip: Money {
        tipSelection.resolveMoney(subtotal: itemsSubtotal, customText: customTipText)
    }

    /// Grand total of the receipt: `itemsSubtotal + resolvedTax + resolvedTip`.
    var grandTotal: Money {
        let total = itemsSubtotal.amountInMinorUnits + resolvedTax.amountInMinorUnits + resolvedTip.amountInMinorUnits
        return Money(amountInMinorUnits: total, currency: currency)
    }

    /// Validates and instantiates the domain `Receipt`. Returns `nil` if participants are empty or validation fails.
    var currentReceipt: Receipt? {
        guard !participants.isEmpty else { return nil }
        do {
            return try Receipt(
                currency: currency,
                participants: participants,
                items: items,
                tax: resolvedTax,
                tip: resolvedTip
            )
        } catch {
            return nil
        }
    }

    /// Live calculation result calculated by `SplitEngine`. Returns `nil` if receipt is invalid.
    var splitResult: ReceiptSplitResult? {
        guard let receipt = currentReceipt else { return nil }
        return try? SplitEngine.calculateSplit(for: receipt)
    }

    /// Indicates whether the receipt is completely valid and ready for final summary.
    var isReceiptValid: Bool {
        currentReceipt != nil
    }

    /// Formatted plain text summary suitable for clipboard copying and sharing.
    var shareableSummaryText: String {
        guard let receipt = currentReceipt, let result = splitResult else {
            return "Agrega participantes y artículos para generar el resumen de la cuenta."
        }

        var lines: [String] = []
        lines.append("🧾 SplitBill — Resumen de Cuenta")
        lines.append("--------------------------------")

        if !receipt.items.isEmpty {
            lines.append("Artículos:")
            for item in receipt.items {
                let lineTotalStr = MoneyFormatter.string(from: item.lineTotal, includeCurrencyCode: false)
                let unitPriceStr = MoneyFormatter.string(from: item.unitPrice, includeCurrencyCode: false)
                if item.quantity > 1 {
                    lines.append("• \(item.name) (x\(item.quantity) a \(unitPriceStr)): \(lineTotalStr)")
                } else {
                    lines.append("• \(item.name): \(lineTotalStr)")
                }
            }
            lines.append("")
        }

        let subtotalStr = MoneyFormatter.string(from: itemsSubtotal)
        lines.append("Subtotal: \(subtotalStr)")

        if resolvedTax.amountInMinorUnits > 0 {
            let taxStr = MoneyFormatter.string(from: resolvedTax)
            lines.append("Impuestos: \(taxStr)")
        }
        if resolvedTip.amountInMinorUnits > 0 {
            let tipStr = MoneyFormatter.string(from: resolvedTip)
            lines.append("Propina: \(tipStr)")
        }

        let totalStr = MoneyFormatter.string(from: grandTotal)
        lines.append("Total General: \(totalStr)")
        lines.append("--------------------------------")
        lines.append("Desglose por Persona:")

        for participant in receipt.participants {
            guard let summary = result.summariesByParticipant[participant.id] else { continue }
            let personTotal = MoneyFormatter.string(from: summary.total)
            let itemsPart = MoneyFormatter.string(from: summary.itemsSubtotal, includeCurrencyCode: false)
            let taxPart = MoneyFormatter.string(from: summary.taxAllocated, includeCurrencyCode: false)
            let tipPart = MoneyFormatter.string(from: summary.tipAllocated, includeCurrencyCode: false)

            lines.append("👤 \(participant.name): \(personTotal)")
            lines.append("   (Consumo: \(itemsPart) | IVA: \(taxPart) | Propina: \(tipPart))")
        }

        lines.append("--------------------------------")
        return lines.joined(separator: "\n")
    }

    // MARK: - Participant Actions

    /// Adds a participant from `newParticipantName`. Trims whitespace and prevents duplicate names.
    func addParticipant() {
        let trimmed = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "El nombre del participante no puede estar vacío."
            return
        }

        guard !participants.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else {
            validationMessage = "Ya existe un participante con el nombre \"\(trimmed)\"."
            return
        }

        do {
            let participant = try Participant(name: trimmed)
            participants.append(participant)
            newParticipantName = ""
            validationMessage = nil
        } catch {
            validationMessage = errorDescription(for: error)
        }
    }

    /// Removes participants at the specified offsets and cleans up references in items.
    func removeParticipant(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { participants[$0].id })
        participants.remove(atOffsets: offsets)
        cleanupParticipantsInItems(removedIDs: removedIDs)
    }

    /// Removes a participant by ID and cleans up references in items.
    func removeParticipant(id: Participant.ID) {
        participants.removeAll { $0.id == id }
        cleanupParticipantsInItems(removedIDs: [id])
    }

    // MARK: - Item Actions

    /// Prepares a new item draft pre-populated with all current participants for equal split.
    func openNewItemDraft() {
        var draft = ReceiptItemDraft()
        draft.equalParticipantIDs = Set(participants.map(\.id))
        draft.selectedParticipantID = participants.first?.id
        activeItemDraft = draft
        validationMessage = nil
    }

    /// Opens an existing item in the draft editor.
    func openEditItemDraft(_ item: ReceiptItem) {
        activeItemDraft = ReceiptItemDraft(from: item)
        validationMessage = nil
    }

    /// Validates and saves the active draft, inserting or updating the item in `items`.
    func saveActiveDraft() {
        guard let draft = activeItemDraft else { return }
        do {
            let item = try draft.buildItem(currency: currency)
            let validIDs = Set(participants.map(\.id))
            try item.splitMode.validate(validParticipants: validIDs)

            if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[existingIndex] = item
            } else {
                items.append(item)
            }
            activeItemDraft = nil
            validationMessage = nil
        } catch {
            validationMessage = errorDescription(for: error)
        }
    }

    /// Deletes items at the specified offsets.
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    /// Deletes an item by ID.
    func deleteItem(id: ReceiptItem.ID) {
        items.removeAll { $0.id == id }
    }

    /// Resets all editor state to pristine initial values.
    func reset() {
        participants.removeAll()
        items.removeAll()
        newParticipantName = ""
        taxText = ""
        tipSelection = .percentage(10)
        customTipText = ""
        activeItemDraft = nil
        validationMessage = nil
    }

    // MARK: - Private Helpers

    private func cleanupParticipantsInItems(removedIDs: Set<Participant.ID>) {
        items = items.compactMap { item in
            switch item.splitMode {
            case .wholeItem(let id):
                if removedIDs.contains(id) {
                    if let fallback = participants.first?.id {
                        return try? ReceiptItem(
                            id: item.id,
                            name: item.name,
                            unitPrice: item.unitPrice,
                            quantity: item.quantity,
                            splitMode: .wholeItem(fallback)
                        )
                    } else {
                        return nil
                    }
                }
                return item

            case .equal(let ids):
                let remaining = ids.subtracting(removedIDs)
                guard !remaining.isEmpty else { return nil }
                return try? ReceiptItem(
                    id: item.id,
                    name: item.name,
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    splitMode: .equal(remaining)
                )

            case .percentage(let pcts):
                var mutable = pcts
                for id in removedIDs { mutable.removeValue(forKey: id) }
                guard !mutable.isEmpty else { return nil }
                // If only 1 participant remains, assign 100% to them so the item remains valid
                if mutable.count == 1, let remainingID = mutable.keys.first {
                    mutable[remainingID] = 100
                }
                if let updatedItem = try? ReceiptItem(
                    id: item.id,
                    name: item.name,
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    splitMode: .percentage(mutable)
                ) {
                    return updatedItem
                } else {
                    // If remaining percentages do not sum to 100%, fallback to equal split among remaining participants
                    return try? ReceiptItem(
                        id: item.id,
                        name: item.name,
                        unitPrice: item.unitPrice,
                        quantity: item.quantity,
                        splitMode: .equal(Set(mutable.keys))
                    )
                }

            case .portion(let ports):
                var mutable = ports
                for id in removedIDs { mutable.removeValue(forKey: id) }
                guard !mutable.isEmpty else { return nil }
                return try? ReceiptItem(
                    id: item.id,
                    name: item.name,
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    splitMode: .portion(mutable)
                )
            }
        }
    }

    private func errorDescription(for error: DomainError) -> String {
        switch error {
        case .emptyParticipantName:
            return "El nombre del participante no puede estar vacío."
        case .emptyItemName:
            return "El nombre del artículo no puede estar vacío."
        case .invalidQuantity(let q):
            return "La cantidad debe ser mayor o igual a 1 (actual: \(q))."
        case .negativeAmount:
            return "El monto ingresado no es válido o es negativo."
        case .currencyMismatch:
            return "Conflicto de monedas en el cálculo."
        case .noParticipantsInReceipt:
            return "Agrega al menos un participante a la cuenta."
        case .noParticipantsAssigned:
            return "Debes asignar el artículo a al menos un participante."
        case .unknownParticipant:
            return "Se asignó un participante desconocido."
        case .invalidPercentageTotal(let total):
            return "Los porcentajes deben sumar exactamente 100% (actual: \(total)%)."
        case .invalidShareValue(let value):
            return "Cada porción o porcentaje debe ser mayor a 0 (actual: \(value))."
        }
    }
}
