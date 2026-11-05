import Foundation
import Testing
@testable import SplitBill

@Suite("ReceiptEditorViewModel Tests")
@MainActor
struct ReceiptEditorViewModelTests {

    // MARK: - Participant Management Tests

    @Test("Adds valid participants and trims whitespace")
    func addsValidParticipants() {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "  Alice  "
        vm.addParticipant()

        #expect(vm.participants.count == 1)
        #expect(vm.participants.first?.name == "Alice")
        #expect(vm.newParticipantName == "")
        #expect(vm.validationMessage == nil)
    }

    @Test("Rejects empty or duplicate participant names")
    func rejectsInvalidParticipantNames() {
        let vm = ReceiptEditorViewModel()

        // Empty
        vm.newParticipantName = "   "
        vm.addParticipant()
        #expect(vm.participants.isEmpty)
        #expect(vm.validationMessage != nil)

        // First valid
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        #expect(vm.participants.count == 1)

        // Duplicate case-insensitive
        vm.newParticipantName = "alice"
        vm.addParticipant()
        #expect(vm.participants.count == 1)
        #expect(vm.validationMessage != nil)
    }

    @Test("Removes participants and cleans up item references")
    func removesParticipants() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        vm.newParticipantName = "Bob"
        vm.addParticipant()

        let aliceID = try #require(vm.participants.first?.id)
        let bobID = try #require(vm.participants.last?.id)

        // Add item split equally between Alice and Bob
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Guacamole"
        vm.activeItemDraft?.unitPriceText = "120.00"
        vm.activeItemDraft?.splitModeKind = .equal
        vm.activeItemDraft?.equalParticipantIDs = [aliceID, bobID]
        vm.saveActiveDraft()

        #expect(vm.items.count == 1)

        // Remove Bob
        vm.removeParticipant(id: bobID)
        #expect(vm.participants.count == 1)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.splitMode == .equal([aliceID]))
    }

    @Test("Removes participant assigned to wholeItem and reassigns to remaining participant")
    func removesParticipantAssignedToWholeItem() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        vm.newParticipantName = "Bob"
        vm.addParticipant()

        let aliceID = try #require(vm.participants.first?.id)
        let bobID = try #require(vm.participants.last?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Cerveza"
        vm.activeItemDraft?.unitPriceText = "60.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = bobID
        vm.saveActiveDraft()

        #expect(vm.items.first?.splitMode == .wholeItem(bobID))

        // When Bob is removed, wholeItem reassigns to Alice
        vm.removeParticipant(id: bobID)
        #expect(vm.participants.count == 1)
        #expect(vm.items.first?.splitMode == .wholeItem(aliceID))
    }

    @Test("Removes participant from percentage item and assigns 100% to sole remaining participant")
    func removesParticipantFromPercentageItem() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        vm.newParticipantName = "Bob"
        vm.addParticipant()

        let aliceID = try #require(vm.participants.first?.id)
        let bobID = try #require(vm.participants.last?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Pizza"
        vm.activeItemDraft?.unitPriceText = "200.00"
        vm.activeItemDraft?.splitModeKind = .percentage
        vm.activeItemDraft?.percentages = [aliceID: 60, bobID: 40]
        vm.saveActiveDraft()

        // When Bob is removed, Alice becomes 100%
        vm.removeParticipant(id: bobID)
        #expect(vm.items.first?.splitMode == .percentage([aliceID: 100]))
    }

    @Test("Deletes items directly by ID and by IndexSet")
    func deletesItems() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Tacos"
        vm.activeItemDraft?.unitPriceText = "50.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Agua"
        vm.activeItemDraft?.unitPriceText = "30.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        #expect(vm.items.count == 2)

        // Delete by ID
        let firstID = try #require(vm.items.first?.id)
        vm.deleteItem(id: firstID)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.name == "Agua")

        // Delete by IndexSet
        vm.deleteItem(at: IndexSet(integer: 0))
        #expect(vm.items.isEmpty)
    }

    // MARK: - Item Draft & Split Mode Tests

    @Test("Adds items via drafts for each split mode")
    func addsItemsViaDrafts() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        vm.newParticipantName = "Bob"
        vm.addParticipant()

        let aliceID = try #require(vm.participants.first?.id)
        let bobID = try #require(vm.participants.last?.id)

        // 1. Whole item (Individual)
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Cerveza"
        vm.activeItemDraft?.unitPriceText = "55.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        // 2. Equal
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Nachos"
        vm.activeItemDraft?.unitPriceText = "140.00"
        vm.activeItemDraft?.splitModeKind = .equal
        vm.activeItemDraft?.equalParticipantIDs = [aliceID, bobID]
        vm.saveActiveDraft()

        // 3. Percentage
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Pizza"
        vm.activeItemDraft?.unitPriceText = "200.00"
        vm.activeItemDraft?.splitModeKind = .percentage
        vm.activeItemDraft?.percentages = [aliceID: 60, bobID: 40]
        vm.saveActiveDraft()

        // 4. Portion
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Jarra de Agua"
        vm.activeItemDraft?.unitPriceText = "60.00"
        vm.activeItemDraft?.splitModeKind = .portion
        vm.activeItemDraft?.portions = [aliceID: 1, bobID: 2]
        vm.saveActiveDraft()

        #expect(vm.items.count == 4)
        #expect(vm.validationMessage == nil)
        #expect(vm.itemsSubtotal == Money(amountInMinorUnits: 45_500, currency: .mxn))
    }

    @Test("Edits existing item via draft in place")
    func editsExistingItem() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Tacos"
        vm.activeItemDraft?.unitPriceText = "100.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        let createdItem = try #require(vm.items.first)
        #expect(createdItem.name == "Tacos")

        // Edit item
        vm.openEditItemDraft(createdItem)
        vm.activeItemDraft?.name = "Orden de 4 Tacos al Pastor"
        vm.activeItemDraft?.unitPriceText = "120.00"
        vm.saveActiveDraft()

        #expect(vm.items.count == 1)
        #expect(vm.items.first?.id == createdItem.id)
        #expect(vm.items.first?.name == "Orden de 4 Tacos al Pastor")
        #expect(vm.items.first?.lineTotal == Money(amountInMinorUnits: 12_000, currency: .mxn))
    }

    @Test("Rejects invalid draft values")
    func rejectsInvalidDrafts() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        // Empty name
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "   "
        vm.activeItemDraft?.unitPriceText = "100.00"
        vm.saveActiveDraft()
        #expect(vm.items.isEmpty)
        #expect(vm.validationMessage != nil)

        // Invalid price
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Burger"
        vm.activeItemDraft?.unitPriceText = "-50"
        vm.saveActiveDraft()
        #expect(vm.items.isEmpty)
        #expect(vm.validationMessage != nil)

        // Percentage does not sum to 100
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Postre"
        vm.activeItemDraft?.unitPriceText = "80.00"
        vm.activeItemDraft?.splitModeKind = .percentage
        vm.activeItemDraft?.percentages = [aliceID: 70]
        vm.saveActiveDraft()
        #expect(vm.items.isEmpty)
        #expect(vm.validationMessage != nil)

        // Negative percentage share
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Flan"
        vm.activeItemDraft?.unitPriceText = "50.00"
        vm.activeItemDraft?.splitModeKind = .percentage
        vm.activeItemDraft?.percentages = [aliceID: -10]
        vm.saveActiveDraft()
        #expect(vm.items.isEmpty)
        #expect(vm.validationMessage != nil)
    }

    // MARK: - Tip & Tax Resolution Tests

    @Test("Resolves tip presets and custom tip accurately")
    func resolvesTipSelection() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Cena"
        vm.activeItemDraft?.unitPriceText = "100.50"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        #expect(vm.itemsSubtotal == Money(amountInMinorUnits: 10_050, currency: .mxn))

        // Preset 0%
        vm.tipSelection = .percentage(0)
        #expect(vm.resolvedTip == Money(amountInMinorUnits: 0, currency: .mxn))

        // Preset 10% (10050 * 10 + 50) / 100 = 100550 / 100 = 1005 cents = $10.05
        vm.tipSelection = .percentage(10)
        #expect(vm.resolvedTip == Money(amountInMinorUnits: 1_005, currency: .mxn))

        // Preset 15% (10050 * 15 + 50) / 100 = 150750 / 100 + 50 = 1508 cents = $15.08
        vm.tipSelection = .percentage(15)
        #expect(vm.resolvedTip == Money(amountInMinorUnits: 1_508, currency: .mxn))

        // Custom tip
        vm.tipSelection = .custom
        vm.customTipText = "25.00"
        #expect(vm.resolvedTip == Money(amountInMinorUnits: 2_500, currency: .mxn))

        // Tax resolution
        vm.taxText = "16.08"
        #expect(vm.resolvedTax == Money(amountInMinorUnits: 1_608, currency: .mxn))
    }

    // MARK: - Live Split & Master Invariant Tests

    @Test("Live split result satisfies Master Allocation Invariant")
    func liveSplitSatisfiesMasterInvariant() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        vm.newParticipantName = "Bob"
        vm.addParticipant()
        vm.newParticipantName = "Carlos"
        vm.addParticipant()

        let aliceID = try #require(vm.participants.first?.id)
        let bobID = vm.participants[1].id
        let carlosID = try #require(vm.participants.last?.id)

        // Item 1: Guacamole $120.00 equal 3 ways
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Guacamole"
        vm.activeItemDraft?.unitPriceText = "120.00"
        vm.activeItemDraft?.splitModeKind = .equal
        vm.activeItemDraft?.equalParticipantIDs = [aliceID, bobID, carlosID]
        vm.saveActiveDraft()

        // Item 2: Tacos $150.00 Alice only
        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Tacos"
        vm.activeItemDraft?.unitPriceText = "150.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        vm.taxText = "43.20"
        vm.tipSelection = .percentage(10)

        #expect(vm.isReceiptValid)
        let splitResult = try #require(vm.splitResult)

        // Master Allocation Invariant: allocated sum == grandTotal
        #expect(splitResult.totalAllocated == vm.grandTotal)

        let sumOfIndividuals = splitResult.summariesByParticipant.values
            .reduce(Int64(0)) { $0 + $1.total.amountInMinorUnits }
        #expect(sumOfIndividuals == vm.grandTotal.amountInMinorUnits)
    }

    @Test("Generates formatted shareable text summary")
    func generatesShareableSummary() throws {
        let vm = ReceiptEditorViewModel()
        #expect(vm.shareableSummaryText.contains("Agrega participantes"))

        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Tacos"
        vm.activeItemDraft?.unitPriceText = "150.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        vm.taxText = "24.00"
        vm.tipSelection = .percentage(10)

        let text = vm.shareableSummaryText
        #expect(text.contains("Resumen de Cuenta"))
        #expect(text.contains("Tacos"))
        #expect(text.contains("Alice"))
        #expect(text.contains("Total General"))
    }

    @Test("Resets all editor state cleanly")
    func resetsEditor() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Alice"
        vm.addParticipant()
        let aliceID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Tacos"
        vm.activeItemDraft?.unitPriceText = "100.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = aliceID
        vm.saveActiveDraft()

        vm.taxText = "16.00"
        vm.tipSelection = .percentage(15)

        #expect(!vm.participants.isEmpty)
        #expect(!vm.items.isEmpty)

        vm.reset()

        #expect(vm.participants.isEmpty)
        #expect(vm.items.isEmpty)
        #expect(vm.taxText == "")
        #expect(vm.customTipText == "")
        #expect(vm.activeItemDraft == nil)
        #expect(vm.validationMessage == nil)
        #expect(vm.itemsSubtotal == Money.zero(currency: .mxn))
        #expect(vm.grandTotal == Money.zero(currency: .mxn))
    }

    // MARK: - Draft Validation & Creation Flow Tests

    @Test("Draft building rejects empty or whitespace-only item name")
    func draftRejectsEmptyItemName() {
        let pID = UUID()
        var draft = ReceiptItemDraft(
            name: "   ",
            unitPriceText: "100.00",
            quantity: 1,
            splitModeKind: .wholeItem,
            selectedParticipantID: pID
        )

        #expect(throws: DomainError.emptyItemName) {
            try draft.buildItem(currency: .mxn)
        }

        draft.name = ""
        #expect(throws: DomainError.emptyItemName) {
            try draft.buildItem(currency: .mxn)
        }
    }

    @Test("Draft building rejects empty or unparseable unit price")
    func draftRejectsEmptyOrInvalidPrice() {
        let pID = UUID()
        var draft = ReceiptItemDraft(
            name: "Tacos",
            unitPriceText: "",
            quantity: 1,
            splitModeKind: .wholeItem,
            selectedParticipantID: pID
        )

        #expect(throws: DomainError.negativeAmount(-1)) {
            try draft.buildItem(currency: .mxn)
        }

        draft.unitPriceText = "   "
        #expect(throws: DomainError.negativeAmount(-1)) {
            try draft.buildItem(currency: .mxn)
        }

        draft.unitPriceText = "abc"
        #expect(throws: DomainError.negativeAmount(-1)) {
            try draft.buildItem(currency: .mxn)
        }

        draft.unitPriceText = "-50.00"
        #expect(throws: DomainError.negativeAmount(-1)) {
            try draft.buildItem(currency: .mxn)
        }
    }

    @Test("Draft building succeeds with zero, integer, and decimal prices")
    func draftBuildsValidPrices() throws {
        let pID = UUID()

        // Zero price ("0.00" and "0")
        let draftZero = ReceiptItemDraft(
            name: "Vaso de Agua Gratis",
            unitPriceText: "0.00",
            quantity: 1,
            splitModeKind: .wholeItem,
            selectedParticipantID: pID
        )
        let itemZero = try draftZero.buildItem(currency: .mxn)
        #expect(itemZero.unitPrice == Money(amountInMinorUnits: 0, currency: .mxn))

        // Integer price ("150")
        let draftInt = ReceiptItemDraft(
            name: "Tacos",
            unitPriceText: "150",
            quantity: 2,
            splitModeKind: .wholeItem,
            selectedParticipantID: pID
        )
        let itemInt = try draftInt.buildItem(currency: .mxn)
        #expect(itemInt.unitPrice == Money(amountInMinorUnits: 15_000, currency: .mxn))
        #expect(itemInt.lineTotal == Money(amountInMinorUnits: 30_000, currency: .mxn))

        // Decimal price ("150.50")
        let draftDecimal = ReceiptItemDraft(
            name: "Cerveza Especial",
            unitPriceText: "150.50",
            quantity: 1,
            splitModeKind: .wholeItem,
            selectedParticipantID: pID
        )
        let itemDecimal = try draftDecimal.buildItem(currency: .mxn)
        #expect(itemDecimal.unitPrice == Money(amountInMinorUnits: 15_050, currency: .mxn))
        #expect(itemDecimal.lineTotal == Money(amountInMinorUnits: 15_050, currency: .mxn))
    }

    @Test("Item creation and saving flow in ReceiptEditorViewModel")
    func itemCreationAndSavingFlow() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Ana"
        vm.addParticipant()
        let anaID = try #require(vm.participants.first?.id)

        // 1. Initial draft creation
        vm.openNewItemDraft()
        #expect(vm.activeItemDraft != nil)
        #expect(vm.validationMessage == nil)

        // 2. Setting valid draft details and saving
        vm.activeItemDraft?.name = "Enchiladas Verdes"
        vm.activeItemDraft?.unitPriceText = "145.50"
        vm.activeItemDraft?.quantity = 2
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = anaID
        vm.saveActiveDraft()

        // 3. Verifying post-save state
        #expect(vm.items.count == 1)
        #expect(vm.activeItemDraft == nil)
        #expect(vm.validationMessage == nil)

        let savedItem = try #require(vm.items.first)
        #expect(savedItem.name == "Enchiladas Verdes")
        #expect(savedItem.quantity == 2)
        #expect(savedItem.unitPrice == Money(amountInMinorUnits: 14_550, currency: .mxn))
        #expect(savedItem.lineTotal == Money(amountInMinorUnits: 29_100, currency: .mxn))
        #expect(savedItem.splitMode == .wholeItem(anaID))
    }
}
