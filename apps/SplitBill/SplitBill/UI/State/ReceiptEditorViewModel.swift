import Foundation
import Observation
import SwiftUI

/// The primary `@MainActor` presentation state model for creating, editing, and splitting a receipt.
///
/// Follows ADR-002 by maintaining strict separation: delegates all business rules and financial
/// calculations to the pure `Domain` layer (`Receipt`, `SplitEngine`, `Money`).
///
/// Supports automatic persistence and multi-receipt sessions through `ReceiptPersistenceStore`.
@Observable
@MainActor
final class ReceiptEditorViewModel {

    // MARK: - Identifiers & Persistence State

    private(set) var receiptID: UUID = UUID()
    var receiptTitle: String = "" {
        didSet { persistCurrentSession() }
    }
    private(set) var savedReceipts: [ReceiptSnapshot] = []

    private var receiptCreatedAt: Date = Date()
    private var isRestoringSession: Bool = false
    private let store: (any ReceiptPersistenceStore)?
    private let ocrService: any ReceiptOCRService
    private let receiptParser: any ReceiptParser
    private let aiParserService: any AIReceiptParserService
    private let aiConsentStore: any AIConsentStoring

    // MARK: - State Properties

    var currency: Currency = .mxn {
        didSet {
            parsedCandidate = nil
            parsedReviewDraft = nil
            persistCurrentSession()
        }
    }
    var participants: [Participant] = []
    var newParticipantName: String = ""
    var items: [ReceiptItem] = []
    var taxText: String = "" {
        didSet { persistCurrentSession() }
    }
    var tipSelection: TipSelection = .percentage(10) {
        didSet { persistCurrentSession() }
    }
    var customTipText: String = "" {
        didSet { persistCurrentSession() }
    }
    var receiptImageData: Data? = nil {
        didSet { persistCurrentSession() }
    }
    private(set) var ocrRawText: String? = nil
    private(set) var lastOCRResult: ReceiptOCRResult? = nil
    private(set) var isRecognizingText: Bool = false

    // MARK: - Parsing & Intelligent Review State

    private(set) var parsedCandidate: ParsedReceiptCandidate? = nil
    var parsedReviewDraft: ParsedReceiptReviewDraft? = nil
    var isShowingParsedReviewSheet: Bool = false
    var isShowingSharePreviewSheet: Bool = false
    var isShowingAIConsentSheet: Bool = false
    private(set) var isParsingWithAI: Bool = false
    private(set) var lastExtractionSource: ExtractionSource = .deterministic
    var importValidationErrorMessage: String? = nil

    /// User has granted informed consent for AI analysis (Guideline 5.1.2(i)).
    var hasGrantedAIConsent: Bool {
        aiConsentStore.hasGrantedConsent
    }

    /// Indicates whether recognized OCR text is present and non-empty.
    var hasOCRText: Bool {
        !(ocrRawText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Number of lines detected by OCR.
    var ocrLineCount: Int {
        lastOCRResult?.lines.count ?? (ocrRawText?.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count ?? 0)
    }

    /// Count of parsed candidate items detected, or 0.
    var detectedParsedItemCount: Int {
        if let candidate = parsedCandidate {
            return candidate.items.count
        }
        if let lines = lastOCRResult?.lines.map(\.text), !lines.isEmpty {
            return receiptParser.parse(lines: lines, currency: currency).items.count
        }
        if let raw = ocrRawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return receiptParser.parse(rawText: raw, currency: currency).items.count
        }
        return 0
    }

    /// Status of reconciliation for the candidate if available.
    var detectedReconciliationStatus: ReceiptReconciliationStatus? {
        if let candidate = parsedCandidate {
            return candidate.reconciliation.status
        }
        if let lines = lastOCRResult?.lines.map(\.text), !lines.isEmpty {
            return receiptParser.parse(lines: lines, currency: currency).reconciliation.status
        }
        if let raw = ocrRawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return receiptParser.parse(rawText: raw, currency: currency).reconciliation.status
        }
        return nil
    }

    var activeItemDraft: ReceiptItemDraft? = nil
    var validationMessage: String? = nil

    // MARK: - Initializer

    init(
        currency: Currency = .mxn,
        store: (any ReceiptPersistenceStore)? = nil,
        ocrService: any ReceiptOCRService = VisionReceiptOCRService(),
        receiptParser: any ReceiptParser = DeterministicReceiptParser(),
        aiParserService: any AIReceiptParserService = HTTPProxyAIReceiptParserService(),
        aiConsentStore: any AIConsentStoring = UserDefaultsAIConsentStore()
    ) {
        self.currency = currency
        self.store = store
        self.ocrService = ocrService
        self.receiptParser = receiptParser
        self.aiParserService = aiParserService
        self.aiConsentStore = aiConsentStore
        self.receiptID = UUID()
        self.receiptCreatedAt = Date()
        loadInitialSession()
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
                id: receiptID,
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

    /// Whether an image of the physical ticket is currently attached to the receipt.
    var hasReceiptImage: Bool {
        receiptImageData != nil
    }

    /// Formatted plain text summary suitable for clipboard copying and sharing.
    var shareableSummaryText: String {
        guard let receipt = currentReceipt, let result = splitResult else {
            return "Agrega participantes y artículos para generar el resumen de la cuenta."
        }

        var lines: [String] = []
        let trimmedTitle = receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            lines.append("🧾 SplitBill — \(trimmedTitle)")
        } else {
            lines.append("🧾 SplitBill — Resumen de Cuenta")
        }
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

    /// Structured card snapshot suitable for visual rendering with `ImageRenderer`.
    var shareCardData: ReceiptShareCardData? {
        guard let receipt = currentReceipt, let result = splitResult, !items.isEmpty, !participants.isEmpty else {
            return nil
        }

        let trimmedTitle = receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmedTitle.isEmpty ? "Resumen de Cuenta" : trimmedTitle

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: Date())

        var rows: [ReceiptShareCardData.ParticipantShareRow] = []
        for participant in receipt.participants {
            guard let summary = result.summariesByParticipant[participant.id] else { continue }

            let assigned: [ReceiptShareCardData.AssignedItemShare] = receipt.items.compactMap { item in
                guard let share = result.itemAllocations[item.id]?[participant.id], share.amountInMinorUnits > 0 else {
                    return nil
                }
                return ReceiptShareCardData.AssignedItemShare(
                    id: item.id,
                    name: item.name,
                    share: share,
                    quantity: item.quantity
                )
            }

            rows.append(
                ReceiptShareCardData.ParticipantShareRow(
                    id: participant.id,
                    name: participant.name,
                    total: summary.total,
                    itemsSubtotal: summary.itemsSubtotal,
                    tax: summary.taxAllocated,
                    tip: summary.tipAllocated,
                    assignedItems: assigned
                )
            )
        }

        return ReceiptShareCardData(
            title: displayTitle,
            dateText: dateString,
            currency: currency,
            itemsSubtotal: itemsSubtotal,
            tax: resolvedTax,
            tip: resolvedTip,
            grandTotal: grandTotal,
            participantRows: rows
        )
    }

    // MARK: - OCR Actions

    /// Triggers optical character recognition on the attached receipt image and automatically parses candidates.
    func recognizeReceiptText() async {
        guard !isRecognizingText, let data = receiptImageData else { return }
        let activeReceiptID = receiptID
        isRecognizingText = true
        defer { isRecognizingText = false }

        do {
            let result = try await ocrService.recognizeText(from: data)
            guard receiptID == activeReceiptID, receiptImageData == data else { return }
            lastOCRResult = result
            ocrRawText = result.rawText
            parsedCandidate = receiptParser.parse(lines: result.lines.map(\.text), currency: currency)
            persistCurrentSession()
        } catch {
            guard receiptID == activeReceiptID, receiptImageData == data else { return }
            validationMessage = "No se pudo reconocer el texto del recibo."
        }
    }

    /// Sets the receipt title from the first non-empty line of recognized OCR text if title is currently empty.
    func applySuggestedTitleFromOCR() {
        guard receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let firstLine = lastOCRResult?.lines.first?.text ?? ocrRawText?.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            receiptTitle = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Parsed Receipt Review & Import Actions

    /// Prepares the interactive review draft from `parsedCandidate` (or OCR text) and opens the review sheet.
    func prepareParsedReceiptReview() {
        if parsedCandidate == nil {
            if let lines = lastOCRResult?.lines.map(\.text), !lines.isEmpty {
                parsedCandidate = receiptParser.parse(lines: lines, currency: currency)
            } else if let raw = ocrRawText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parsedCandidate = receiptParser.parse(rawText: raw, currency: currency)
            }
        }

        guard let candidate = parsedCandidate else { return }
        lastExtractionSource = .deterministic
        parsedReviewDraft = ParsedReceiptReviewDraft(from: candidate)
        importValidationErrorMessage = nil
        isShowingParsedReviewSheet = true
    }

    // MARK: - AI Receipt Parsing Actions

    /// Triggers AI-assisted receipt analysis. Prompts for informed consent if not yet granted (Guideline 5.1.2(i)).
    func requestAIReceiptParsing() async {
        guard !isParsingWithAI else { return }
        guard aiConsentStore.hasGrantedConsent else {
            isShowingAIConsentSheet = true
            return
        }

        guard let rawText = ocrRawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Extrae el texto del ticket con OCR antes de analizar con IA."
            return
        }

        let activeReceiptID = receiptID
        isParsingWithAI = true
        defer { isParsingWithAI = false }

        do {
            let result = try await aiParserService.parseReceiptWithAI(
                rawText: rawText,
                currency: currency,
                userConsentConfirmed: true
            )
            guard receiptID == activeReceiptID else { return }
            parsedCandidate = result.candidate
            lastExtractionSource = .aiProxy(provider: result.providerUsed)
            parsedReviewDraft = ParsedReceiptReviewDraft(from: result.candidate)
            importValidationErrorMessage = nil
            isShowingParsedReviewSheet = true
            persistCurrentSession()
        } catch {
            guard receiptID == activeReceiptID else { return }
            validationMessage = "No se pudo completar la extracción con IA: \(error.localizedDescription)"
        }
    }

    /// Records explicit informed consent and proceeds with AI receipt analysis.
    func grantAIConsentAndParse() async {
        aiConsentStore.grantConsent()
        isShowingAIConsentSheet = false
        await requestAIReceiptParsing()
    }

    /// Revokes user consent for third-party AI processing.
    func revokeAIConsent() {
        aiConsentStore.revokeConsent()
    }

    /// Dismisses the review sheet and discards the unconfirmed draft.
    func dismissParsedReceiptReview() {
        isShowingParsedReviewSheet = false
        parsedReviewDraft = nil
        importValidationErrorMessage = nil
    }

    /// Validates and imports the confirmed items and amounts from the active review draft into the live receipt.
    ///
    /// - Parameter replaceExistingItems: If `true`, replaces existing items; otherwise appends to them.
    /// - Returns: `true` if import succeeded, `false` if validation failed.
    @discardableResult
    func confirmParsedReceiptImport(replaceExistingItems: Bool) -> Bool {
        guard let draft = parsedReviewDraft else { return false }

        // Invariant gate: at least one participant is required before assigning items.
        guard !participants.isEmpty else {
            importValidationErrorMessage = "Agrega al menos un comensal antes de importar los artículos del recibo."
            return false
        }

        let includedItems = draft.items.filter(\.isIncluded)
        guard !includedItems.isEmpty else {
            importValidationErrorMessage = "No hay artículos seleccionados para importar."
            return false
        }

        // Validate each item has valid non-empty name and positive price
        let allParticipantIDs = Set(participants.map(\.id))
        var importedItems: [ReceiptItem] = []

        for itemDraft in includedItems {
            let trimmedName = itemDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                importValidationErrorMessage = "Todos los artículos seleccionados deben tener un nombre válido."
                return false
            }

            guard let unitPrice = itemDraft.parsedUnitPrice(currency: currency), unitPrice.amountInMinorUnits > 0 else {
                importValidationErrorMessage = "El artículo \"\(trimmedName)\" tiene un precio unitario inválido o de $0.00."
                return false
            }

            guard itemDraft.quantity >= 1 else {
                importValidationErrorMessage = "La cantidad del artículo \"\(trimmedName)\" debe ser al menos 1."
                return false
            }

            do {
                let receiptItem = try ReceiptItem(
                    name: trimmedName,
                    unitPrice: unitPrice,
                    quantity: itemDraft.quantity,
                    splitMode: .equal(allParticipantIDs)
                )
                importedItems.append(receiptItem)
            } catch {
                importValidationErrorMessage = errorDescription(for: error)
                return false
            }
        }

        // Update items
        if replaceExistingItems {
            items = importedItems
        } else {
            items.append(contentsOf: importedItems)
        }

        // Suggested merchant title
        let trimmedMerchant = draft.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !trimmedMerchant.isEmpty {
            receiptTitle = trimmedMerchant
        }

        // Detected tax
        if draft.includeDetectedTax, let tax = draft.resolvedTax {
            taxText = MoneyFormatter.decimalString(from: tax)
        }

        // Detected tip
        if draft.includeDetectedTip, let tip = draft.resolvedTip {
            tipSelection = .custom
            customTipText = MoneyFormatter.decimalString(from: tip)
        }

        // Clean up sheet state and persist
        isShowingParsedReviewSheet = false
        parsedReviewDraft = nil
        importValidationErrorMessage = nil
        persistCurrentSession()
        return true
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
            persistCurrentSession()
        } catch {
            validationMessage = errorDescription(for: error)
        }
    }

    /// Removes participants at the specified offsets and cleans up references in items.
    func removeParticipant(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { participants[$0].id })
        participants.remove(atOffsets: offsets)
        cleanupParticipantsInItems(removedIDs: removedIDs)
        persistCurrentSession()
    }

    /// Removes a participant by ID and cleans up references in items.
    func removeParticipant(id: Participant.ID) {
        participants.removeAll { $0.id == id }
        cleanupParticipantsInItems(removedIDs: [id])
        persistCurrentSession()
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
            persistCurrentSession()
        } catch {
            validationMessage = errorDescription(for: error)
        }
    }

    /// Deletes items at the specified offsets.
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persistCurrentSession()
    }

    /// Deletes an item by ID.
    func deleteItem(id: ReceiptItem.ID) {
        items.removeAll { $0.id == id }
        persistCurrentSession()
    }

    /// Resets all editor state to pristine initial values.
    func reset() {
        startNewReceipt()
    }

    // MARK: - Receipt Image Actions

    /// Processes and attaches receipt image data (normalizing orientation and downscaling).
    func attachReceiptImageData(_ rawData: Data) {
        guard let processed = ReceiptImageProcessor.process(data: rawData) else {
            validationMessage = "No se pudo procesar la imagen seleccionada."
            return
        }
        ocrRawText = nil
        lastOCRResult = nil
        parsedCandidate = nil
        parsedReviewDraft = nil
        isShowingParsedReviewSheet = false
        isShowingAIConsentSheet = false
        isParsingWithAI = false
        lastExtractionSource = .deterministic
        receiptImageData = processed
        validationMessage = nil
    }

    /// Attaches a synthetic sample receipt image for mock, demo, and testing workflows.
    func attachSampleReceipt(_ preset: SampleReceiptPreset) {
        ocrRawText = nil
        lastOCRResult = nil
        parsedCandidate = nil
        parsedReviewDraft = nil
        isShowingParsedReviewSheet = false
        isShowingAIConsentSheet = false
        isParsingWithAI = false
        lastExtractionSource = .deterministic
        receiptImageData = SampleReceiptImageGenerator.generateImageData(for: preset)
        validationMessage = nil
    }

    /// Removes the attached receipt image and persists the updated session.
    func removeReceiptImage() {
        ocrRawText = nil
        lastOCRResult = nil
        parsedCandidate = nil
        parsedReviewDraft = nil
        isShowingParsedReviewSheet = false
        isShowingAIConsentSheet = false
        isParsingWithAI = false
        lastExtractionSource = .deterministic
        receiptImageData = nil
        validationMessage = nil
    }

    // MARK: - Session & Persistence Actions

    /// Refreshes `savedReceipts` from the persistence store.
    func refreshSavedReceipts() {
        guard let store else {
            savedReceipts = []
            return
        }
        do {
            savedReceipts = try store.fetchAll()
        } catch {
            savedReceipts = []
        }
    }

    /// Loads the latest saved receipt session if available.
    func loadInitialSession() {
        refreshSavedReceipts()
        if let latest = savedReceipts.first {
            loadSnapshot(latest)
        }
    }

    /// Restores view model state from a `ReceiptSnapshot` without triggering redundant auto-saves.
    func loadSnapshot(_ snapshot: ReceiptSnapshot) {
        isRestoringSession = true
        defer { isRestoringSession = false }

        receiptID = snapshot.id
        receiptCreatedAt = snapshot.createdAt
        receiptTitle = snapshot.title
        currency = snapshot.currency
        participants = snapshot.participants
        items = snapshot.items
        receiptImageData = snapshot.receiptImageData
        ocrRawText = snapshot.ocrRawText
        lastOCRResult = nil
        isRecognizingText = false
        parsedCandidate = nil
        parsedReviewDraft = nil
        isShowingParsedReviewSheet = false
        isShowingAIConsentSheet = false
        isParsingWithAI = false
        lastExtractionSource = .deterministic
        importValidationErrorMessage = nil
        taxText = snapshot.tax.amountInMinorUnits > 0 ? MoneyFormatter.decimalString(from: snapshot.tax) : ""
        tipSelection = snapshot.tipSelection
        if let customUnits = snapshot.customTipMinorUnits, customUnits > 0 {
            customTipText = MoneyFormatter.decimalString(from: Money(amountInMinorUnits: customUnits, currency: snapshot.currency))
        } else {
            customTipText = ""
        }
        activeItemDraft = nil
        validationMessage = nil
    }

    /// Persists the active session state as a `ReceiptSnapshot` if content exists.
    func persistCurrentSession() {
        guard !isRestoringSession, let store else { return }
        let trimmedTitle = receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasOCR = !(ocrRawText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasContent = !trimmedTitle.isEmpty || !participants.isEmpty || !items.isEmpty || receiptImageData != nil || hasOCR
        guard hasContent else {
            if savedReceipts.contains(where: { $0.id == receiptID }) {
                try? store.delete(id: receiptID)
                refreshSavedReceipts()
            }
            return
        }

        let customTipUnits: Int64 = tipSelection == .custom
            ? (MoneyFormatter.parseMinorUnits(from: customTipText, currency: currency) ?? 0)
            : 0

        let snapshot = ReceiptSnapshot(
            id: receiptID,
            title: receiptTitle,
            createdAt: receiptCreatedAt,
            updatedAt: Date(),
            currency: currency,
            participants: participants,
            items: items,
            tax: resolvedTax,
            tipSelection: tipSelection,
            customTipMinorUnits: customTipUnits,
            receiptImageData: receiptImageData,
            ocrRawText: ocrRawText
        )

        do {
            try store.save(snapshot)
            refreshSavedReceipts()
        } catch {
            // Persistence errors fail gracefully to avoid disrupting UI flow
        }
    }

    /// Clears the active session and prepares a new receipt.
    func startNewReceipt() {
        isRestoringSession = true
        defer { isRestoringSession = false }

        receiptID = UUID()
        receiptCreatedAt = Date()
        receiptTitle = ""
        participants.removeAll()
        items.removeAll()
        receiptImageData = nil
        ocrRawText = nil
        lastOCRResult = nil
        isRecognizingText = false
        parsedCandidate = nil
        parsedReviewDraft = nil
        isShowingParsedReviewSheet = false
        isShowingAIConsentSheet = false
        isParsingWithAI = false
        lastExtractionSource = .deterministic
        importValidationErrorMessage = nil
        newParticipantName = ""
        taxText = ""
        tipSelection = .percentage(10)
        customTipText = ""
        activeItemDraft = nil
        validationMessage = nil
    }

    /// Selects and restores a saved receipt by its identifier.
    func selectReceipt(id: UUID) {
        if let snapshot = savedReceipts.first(where: { $0.id == id }) {
            loadSnapshot(snapshot)
        } else if let snapshot = try? store?.fetch(id: id) {
            loadSnapshot(snapshot)
            refreshSavedReceipts()
        }
    }

    /// Deletes a saved receipt by ID, updating `savedReceipts` and falling back cleanly if active.
    func deleteSavedReceipt(id: UUID) {
        do {
            try store?.delete(id: id)
        } catch {
            // Fail gracefully
        }
        refreshSavedReceipts()

        if id == receiptID {
            if let next = savedReceipts.first {
                loadSnapshot(next)
            } else {
                startNewReceipt()
            }
        }
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
        case .invalidShareCode:
            return "El código para compartir debe tener 8 caracteres válidos."
        case .sessionExpired:
            return "La sesión compartida ha expirado o fue cerrada."
        case .versionConflict:
            return "La sesión se actualizó en otro dispositivo; sincronizando cambios."
        }
    }
}
