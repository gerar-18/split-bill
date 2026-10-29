import Foundation
import Testing
@testable import SplitBill

@Suite("ReceiptPersistence Tests")
@MainActor
struct ReceiptPersistenceTests {

    @Test("Round-trips receipt with all 4 split modes and verifies exact split allocation")
    func roundTripAllSplitModes() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let ana = try Participant(name: "Ana")
        let beto = try Participant(name: "Beto")
        let carlos = try Participant(name: "Carlos")

        let item1 = try ReceiptItem(
            name: "Tacos al Pastor",
            unitPrice: Money(amountInMinorUnits: 15_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(ana.id)
        )
        let item2 = try ReceiptItem(
            name: "Guacamole",
            unitPrice: Money(amountInMinorUnits: 9_000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([ana.id, beto.id])
        )
        let item3 = try ReceiptItem(
            name: "Ribeye Steak",
            unitPrice: Money(amountInMinorUnits: 60_000, currency: .mxn),
            quantity: 1,
            splitMode: .percentage([ana.id: 20, beto.id: 30, carlos.id: 50])
        )
        let item4 = try ReceiptItem(
            name: "Jarra de Cerveza",
            unitPrice: Money(amountInMinorUnits: 24_000, currency: .mxn),
            quantity: 1,
            splitMode: .portion([ana.id: 1, beto.id: 2, carlos.id: 1])
        )

        let originalSnapshot = ReceiptSnapshot(
            id: UUID(),
            title: "Cena en Sonora Grill",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            currency: .mxn,
            participants: [ana, beto, carlos],
            items: [item1, item2, item3, item4],
            tax: Money(amountInMinorUnits: 10_000, currency: .mxn),
            tipSelection: .percentage(15)
        )

        try store.save(originalSnapshot)

        let loaded = try store.fetch(id: originalSnapshot.id)
        #expect(loaded != nil)
        guard let loaded else { return }

        #expect(loaded.id == originalSnapshot.id)
        #expect(loaded.title == originalSnapshot.title)
        #expect(loaded.currency == originalSnapshot.currency)
        #expect(loaded.participants == originalSnapshot.participants)
        #expect(loaded.items == originalSnapshot.items)
        #expect(loaded.tax == originalSnapshot.tax)
        #expect(loaded.tipSelection == originalSnapshot.tipSelection)
        #expect(loaded.itemsSubtotal == originalSnapshot.itemsSubtotal)
        #expect(loaded.resolvedTip == originalSnapshot.resolvedTip)
        #expect(loaded.grandTotal == originalSnapshot.grandTotal)

        let domain1 = try originalSnapshot.toDomainReceipt()
        let domain2 = try loaded.toDomainReceipt()
        #expect(domain1 == domain2)

        let split1 = try SplitEngine.calculateSplit(for: domain1)
        let split2 = try SplitEngine.calculateSplit(for: domain2)
        #expect(split1 == split2)
        #expect(split2.totalAllocated == domain2.total)
    }

    @Test("Strictly preserves canonical participant order across persistence cycle")
    func preservesCanonicalParticipantOrder() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let carlos = try Participant(name: "Carlos")
        let ana = try Participant(name: "Ana")
        let beto = try Participant(name: "Beto")

        let snapshot = ReceiptSnapshot(
            title: "Orden Canónica",
            participants: [carlos, ana, beto]
        )

        try store.save(snapshot)

        let loaded = try store.fetch(id: snapshot.id)
        #expect(loaded != nil)
        #expect(loaded?.participants.map(\.name) == ["Carlos", "Ana", "Beto"])
        #expect(loaded?.participants[0].id == carlos.id)
        #expect(loaded?.participants[1].id == ana.id)
        #expect(loaded?.participants[2].id == beto.id)
    }

    @Test("Upsert updates existing receipt without creating duplicate records")
    func upsertUpdatesExistingReceipt() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let id = UUID()
        let p1 = try Participant(name: "David")
        var snapshot = ReceiptSnapshot(id: id, title: "Versión 1", participants: [p1])
        try store.save(snapshot)

        var all = try store.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "Versión 1")

        let p2 = try Participant(name: "Elena")
        snapshot.title = "Versión 2 Modificada"
        snapshot.participants.append(p2)
        snapshot.updatedAt = Date()
        try store.save(snapshot)

        all = try store.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "Versión 2 Modificada")
        #expect(all.first?.participants.count == 2)
    }

    @Test("fetchAll returns receipts ordered by updatedAt descending")
    func fetchAllReturnsOrderedByUpdatedAt() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let p = try Participant(name: "Persona")

        let receiptOld = ReceiptSnapshot(
            title: "Viejo",
            updatedAt: Date(timeIntervalSince1970: 1_000),
            participants: [p]
        )
        let receiptNewest = ReceiptSnapshot(
            title: "Más Reciente",
            updatedAt: Date(timeIntervalSince1970: 3_000),
            participants: [p]
        )
        let receiptMiddle = ReceiptSnapshot(
            title: "Intermedio",
            updatedAt: Date(timeIntervalSince1970: 2_000),
            participants: [p]
        )

        try store.save(receiptOld)
        try store.save(receiptNewest)
        try store.save(receiptMiddle)

        let fetched = try store.fetchAll()
        #expect(fetched.count == 3)
        #expect(fetched[0].id == receiptNewest.id)
        #expect(fetched[1].id == receiptMiddle.id)
        #expect(fetched[2].id == receiptOld.id)
    }

    @Test("delete removes receipt from store")
    func deleteRemovesReceipt() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let p = try Participant(name: "Persona")
        let snapshot = ReceiptSnapshot(title: "Por Eliminar", participants: [p])
        try store.save(snapshot)

        #expect(try store.fetch(id: snapshot.id) != nil)
        try store.delete(id: snapshot.id)

        #expect(try store.fetch(id: snapshot.id) == nil)
        #expect(try store.fetchAll().isEmpty)
    }

    @Test("fetch with non-existent ID cleanly returns nil without throwing")
    func fetchNonExistentReceiptReturnsNil() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let nonExistentID = UUID()

        let result = try store.fetch(id: nonExistentID)
        #expect(result == nil)

        // With an existing record present
        let snapshot = ReceiptSnapshot(title: "Existente")
        try store.save(snapshot)

        #expect(try store.fetch(id: nonExistentID) == nil)
        #expect(try store.fetch(id: snapshot.id) != nil)
    }

    @Test("Draft snapshot with zero participants or items persists and round-trips safely")
    func emptyDraftSnapshotRoundTrip() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let draft = ReceiptSnapshot(
            title: "Borrador Vacío",
            tipSelection: .custom,
            customTipMinorUnits: 4_500
        )
        try store.save(draft)

        let loaded = try store.fetch(id: draft.id)
        #expect(loaded != nil)
        #expect(loaded?.participants.isEmpty == true)
        #expect(loaded?.items.isEmpty == true)
        #expect(loaded?.itemsSubtotal == Money.zero(currency: .mxn))
        #expect(loaded?.tipSelection == .custom)
        #expect(loaded?.customTipMinorUnits == 4_500)
        #expect(loaded?.resolvedTip == Money(amountInMinorUnits: 4_500, currency: .mxn))
        #expect(loaded?.grandTotal == Money(amountInMinorUnits: 4_500, currency: .mxn))
    }

    // MARK: - ReceiptEditorViewModel Session & Persistence Tests

    @Test("ReceiptEditorViewModel persists changes and restores complete session on relaunch")
    func viewModelRelaunchRestoresCompleteSession() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        // 1. Launch first view model instance
        let vm1 = ReceiptEditorViewModel(currency: .mxn, store: store)
        vm1.receiptTitle = "Cena con Amigos"

        vm1.newParticipantName = "Ana"
        vm1.addParticipant()
        vm1.newParticipantName = "Beto"
        vm1.addParticipant()

        let anaID = try #require(vm1.participants.first?.id)
        let betoID = try #require(vm1.participants.last?.id)

        // Add item 1: Tacos for Ana ($150.00)
        vm1.openNewItemDraft()
        vm1.activeItemDraft?.name = "Tacos"
        vm1.activeItemDraft?.unitPriceText = "150.00"
        vm1.activeItemDraft?.splitModeKind = .wholeItem
        vm1.activeItemDraft?.selectedParticipantID = anaID
        vm1.saveActiveDraft()

        // Add item 2: Guacamole shared ($100.00)
        vm1.openNewItemDraft()
        vm1.activeItemDraft?.name = "Guacamole"
        vm1.activeItemDraft?.unitPriceText = "100.00"
        vm1.activeItemDraft?.splitModeKind = .equal
        vm1.activeItemDraft?.equalParticipantIDs = [anaID, betoID]
        vm1.saveActiveDraft()

        vm1.taxText = "40.00"
        vm1.tipSelection = .percentage(15)

        // Verify vm1 state and that it auto-saved to store
        #expect(vm1.savedReceipts.count == 1)
        let saved = try #require(try store.fetch(id: vm1.receiptID))
        #expect(saved.title == "Cena con Amigos")
        #expect(saved.participants.count == 2)
        #expect(saved.items.count == 2)

        // 2. Launch second view model instance pointing to same store (simulates app relaunch)
        let vm2 = ReceiptEditorViewModel(currency: .mxn, store: store)

        #expect(vm2.receiptID == vm1.receiptID)
        #expect(vm2.receiptTitle == "Cena con Amigos")
        #expect(vm2.participants.map(\.name) == ["Ana", "Beto"])
        #expect(vm2.items.count == 2)
        #expect(vm2.items[0].name == "Tacos")
        #expect(vm2.items[1].name == "Guacamole")
        #expect(vm2.taxText == "40.00")
        #expect(vm2.resolvedTax == Money(amountInMinorUnits: 4_000, currency: .mxn))
        #expect(vm2.tipSelection == .percentage(15))
        #expect(vm2.itemsSubtotal == vm1.itemsSubtotal)
        #expect(vm2.resolvedTip == vm1.resolvedTip)
        #expect(vm2.grandTotal == vm1.grandTotal)
        #expect(vm2.isReceiptValid == true)

        let split1 = try #require(vm1.splitResult)
        let split2 = try #require(vm2.splitResult)
        #expect(split1 == split2)

        #expect(vm2.shareableSummaryText.contains("🧾 SplitBill — Cena con Amigos"))
    }

    @Test("ReceiptEditorViewModel persists custom tip selection and restores it accurately")
    func viewModelCustomTipRestoration() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let vm1 = ReceiptEditorViewModel(currency: .mxn, store: store)
        vm1.receiptTitle = "Mesa VIP"
        vm1.newParticipantName = "Hugo"
        vm1.addParticipant()
        let hugoID = try #require(vm1.participants.first?.id)

        vm1.openNewItemDraft()
        vm1.activeItemDraft?.name = "Corte Wagyu"
        vm1.activeItemDraft?.unitPriceText = "800.00"
        vm1.activeItemDraft?.splitModeKind = .wholeItem
        vm1.activeItemDraft?.selectedParticipantID = hugoID
        vm1.saveActiveDraft()

        vm1.tipSelection = .custom
        vm1.customTipText = "125.50"

        let vm2 = ReceiptEditorViewModel(currency: .mxn, store: store)
        #expect(vm2.tipSelection == .custom)
        #expect(vm2.customTipText == "125.50")
        #expect(vm2.resolvedTip == Money(amountInMinorUnits: 12_550, currency: .mxn))
        #expect(vm2.grandTotal == Money(amountInMinorUnits: 92_550, currency: .mxn))
    }

    @Test("ReceiptEditorViewModel supports starting a new receipt and switching between saved receipts")
    func viewModelStartNewReceiptAndSwitching() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        // 1. Create Receipt 1
        let vm = ReceiptEditorViewModel(currency: .mxn, store: store)
        vm.receiptTitle = "Comida Italiana"
        vm.newParticipantName = "Carlos"
        vm.addParticipant()
        let carlosID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Pasta Carbonara"
        vm.activeItemDraft?.unitPriceText = "220.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = carlosID
        vm.saveActiveDraft()

        let receipt1ID = vm.receiptID
        #expect(vm.savedReceipts.count == 1)

        // 2. Start new receipt
        vm.startNewReceipt()
        #expect(vm.receiptID != receipt1ID)
        #expect(vm.receiptTitle == "")
        #expect(vm.participants.isEmpty)
        #expect(vm.items.isEmpty)
        #expect(vm.taxText == "")
        #expect(vm.grandTotal == Money.zero(currency: .mxn))

        // 3. Create Receipt 2
        vm.receiptTitle = "Café y Postre"
        vm.newParticipantName = "Diana"
        vm.addParticipant()
        let dianaID = try #require(vm.participants.first?.id)

        vm.openNewItemDraft()
        vm.activeItemDraft?.name = "Cheesecake"
        vm.activeItemDraft?.unitPriceText = "95.00"
        vm.activeItemDraft?.splitModeKind = .wholeItem
        vm.activeItemDraft?.selectedParticipantID = dianaID
        vm.saveActiveDraft()

        let receipt2ID = vm.receiptID
        #expect(vm.savedReceipts.count == 2)

        // 4. Switch back to Receipt 1
        vm.selectReceipt(id: receipt1ID)
        #expect(vm.receiptID == receipt1ID)
        #expect(vm.receiptTitle == "Comida Italiana")
        #expect(vm.participants.map(\.name) == ["Carlos"])
        #expect(vm.items.first?.name == "Pasta Carbonara")

        // 5. Switch to Receipt 2
        vm.selectReceipt(id: receipt2ID)
        #expect(vm.receiptID == receipt2ID)
        #expect(vm.receiptTitle == "Café y Postre")
        #expect(vm.participants.map(\.name) == ["Diana"])
        #expect(vm.items.first?.name == "Cheesecake")
    }

    @Test("ReceiptEditorViewModel deletes saved receipts and falls back cleanly")
    func viewModelDeleteSavedReceipt() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let vm = ReceiptEditorViewModel(currency: .mxn, store: store)

        // Create Receipt 1
        vm.receiptTitle = "Cuenta Uno"
        vm.newParticipantName = "Elena"
        vm.addParticipant()
        let r1ID = vm.receiptID

        // Create Receipt 2
        vm.startNewReceipt()
        vm.receiptTitle = "Cuenta Dos"
        vm.newParticipantName = "Fernando"
        vm.addParticipant()
        let r2ID = vm.receiptID

        #expect(vm.savedReceipts.count == 2)
        #expect(vm.receiptID == r2ID)

        // 1. Delete inactive receipt (r1ID) -> active receipt remains unchanged
        vm.deleteSavedReceipt(id: r1ID)
        #expect(vm.savedReceipts.count == 1)
        #expect(vm.receiptID == r2ID)
        #expect(try store.fetch(id: r1ID) == nil)

        // Recreate a secondary receipt to test active deletion fallback
        vm.startNewReceipt()
        vm.receiptTitle = "Cuenta Tres"
        vm.newParticipantName = "Gabriela"
        vm.addParticipant()
        let r3ID = vm.receiptID

        #expect(vm.savedReceipts.count == 2)
        #expect(vm.receiptID == r3ID)

        // 2. Delete active receipt (r3ID) when another receipt exists -> falls back to r2ID
        vm.deleteSavedReceipt(id: r3ID)
        #expect(vm.savedReceipts.count == 1)
        #expect(vm.receiptID == r2ID)
        #expect(vm.receiptTitle == "Cuenta Dos")
        #expect(try store.fetch(id: r3ID) == nil)

        // 3. Delete sole remaining active receipt (r2ID) -> falls back to startNewReceipt()
        vm.deleteSavedReceipt(id: r2ID)
        #expect(vm.savedReceipts.isEmpty)
        #expect(try store.fetch(id: r2ID) == nil)
        #expect(vm.receiptID != r2ID)
        #expect(vm.receiptTitle == "")
        #expect(vm.participants.isEmpty)
    }
}
