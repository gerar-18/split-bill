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
}
