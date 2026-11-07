import Foundation
import Testing
import UIKit
@testable import SplitBill

@Suite("Receipt Share Card & ImageRenderer Tests")
struct ReceiptShareCardTests {

    @Test("shareCardData returns nil when receipt has no items or no participants")
    @MainActor
    func shareCardDataReturnsNilWhenIncomplete() {
        let vm = ReceiptEditorViewModel()
        #expect(vm.shareCardData == nil)

        let p1 = try! Participant(name: "Ana")
        vm.participants = [p1]
        #expect(vm.shareCardData == nil)

        vm.participants = []
        vm.items = [
            try! ReceiptItem(
                name: "Tacos",
                unitPrice: Money(amountInMinorUnits: 15000, currency: .mxn),
                quantity: 1,
                splitMode: .equal([p1.id])
            )
        ]
        #expect(vm.shareCardData == nil)
    }

    @Test("shareCardData accurately captures totals and preserves Master Conservation Invariant")
    @MainActor
    func shareCardDataCapturesTotalsAndPreservesConservation() throws {
        let vm = ReceiptEditorViewModel()
        let p1 = try Participant(name: "Ana García")
        let p2 = try Participant(name: "Carlos Rivera")
        let p3 = try Participant(name: "Bystander")
        vm.participants = [p1, p2, p3]
        vm.receiptTitle = "Taquería El Pastor"

        let item1 = try ReceiptItem(
            name: "Orden Tacos al Pastor",
            unitPrice: Money(amountInMinorUnits: 17000, currency: .mxn),
            quantity: 2,
            splitMode: .equal([p1.id, p2.id])
        )
        let item2 = try ReceiptItem(
            name: "Agua de Horchata",
            unitPrice: Money(amountInMinorUnits: 4500, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(p1.id)
        )
        vm.items = [item1, item2]
        vm.taxText = "61.60"
        vm.tipSelection = .percentage(15)

        guard let cardData = vm.shareCardData else {
            Issue.record("Expected valid shareCardData")
            return
        }

        #expect(cardData.title == "Taquería El Pastor")
        #expect(cardData.currency == .mxn)
        #expect(cardData.itemsSubtotal == vm.itemsSubtotal)
        #expect(cardData.tax == vm.resolvedTax)
        #expect(cardData.tip == vm.resolvedTip)
        #expect(cardData.grandTotal == vm.grandTotal)
        #expect(cardData.participantRows.count == 3)

        // Master Conservation Invariant: Sum of participant totals must equal grand total
        let sumOfParticipantTotals = cardData.participantRows
            .map(\.total.amountInMinorUnits)
            .reduce(0, +)
        #expect(sumOfParticipantTotals == cardData.grandTotal.amountInMinorUnits)

        // Verify bystander (p3) has 0 assigned items
        let bystanderRow = try #require(cardData.participantRows.first { $0.id == p3.id })
        #expect(bystanderRow.itemsSubtotal.amountInMinorUnits == 0)
        #expect(bystanderRow.assignedItems.isEmpty)

        // Verify consuming participant (p1) has assigned items
        let p1Row = try #require(cardData.participantRows.first { $0.id == p1.id })
        #expect(p1Row.assignedItems.count == 2)
        #expect(p1Row.total.amountInMinorUnits > 0)
    }

    @Test("ReceiptCardRenderer produces high-resolution PNG image with valid PNG header")
    @MainActor
    func receiptCardRendererProducesValidRetinaPNG() throws {
        let p1 = try Participant(name: "Ana")
        let p2 = try Participant(name: "Carlos")

        let testData = ReceiptShareCardData(
            title: "Cena de Prueba",
            dateText: "6 nov 2026",
            currency: .mxn,
            itemsSubtotal: Money(amountInMinorUnits: 20000, currency: .mxn),
            tax: Money(amountInMinorUnits: 3200, currency: .mxn),
            tip: Money(amountInMinorUnits: 2000, currency: .mxn),
            grandTotal: Money(amountInMinorUnits: 25200, currency: .mxn),
            participantRows: [
                ReceiptShareCardData.ParticipantShareRow(
                    id: p1.id,
                    name: p1.name,
                    total: Money(amountInMinorUnits: 12600, currency: .mxn),
                    itemsSubtotal: Money(amountInMinorUnits: 10000, currency: .mxn),
                    tax: Money(amountInMinorUnits: 1600, currency: .mxn),
                    tip: Money(amountInMinorUnits: 1000, currency: .mxn),
                    assignedItems: [
                        ReceiptShareCardData.AssignedItemShare(
                            id: UUID(),
                            name: "Platillo",
                            share: Money(amountInMinorUnits: 10000, currency: .mxn),
                            quantity: 1
                        )
                    ]
                ),
                ReceiptShareCardData.ParticipantShareRow(
                    id: p2.id,
                    name: p2.name,
                    total: Money(amountInMinorUnits: 12600, currency: .mxn),
                    itemsSubtotal: Money(amountInMinorUnits: 10000, currency: .mxn),
                    tax: Money(amountInMinorUnits: 1600, currency: .mxn),
                    tip: Money(amountInMinorUnits: 1000, currency: .mxn),
                    assignedItems: [
                        ReceiptShareCardData.AssignedItemShare(
                            id: UUID(),
                            name: "Platillo",
                            share: Money(amountInMinorUnits: 10000, currency: .mxn),
                            quantity: 1
                        )
                    ]
                )
            ]
        )

        // 1. Test Classic Light Theme
        let lightImage = try #require(
            ReceiptCardRenderer.renderImage(data: testData, theme: .classicLight, showsItemizedDetails: true)
        )
        // Logical width 380pt * scale 3.0 = 1140 px width
        #expect(lightImage.size.width == 380)
        #expect(lightImage.cgImage?.width == 1140)

        let lightPNG = try #require(
            ReceiptCardRenderer.renderPNGData(data: testData, theme: .classicLight, showsItemizedDetails: true)
        )
        #expect(lightPNG.isEmpty == false)

        // Verify standard PNG magic bytes: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
        let pngHeader = [UInt8](lightPNG.prefix(8))
        #expect(pngHeader == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        // 2. Test Midnight Dark Theme without itemized details
        let darkPNG = try #require(
            ReceiptCardRenderer.renderPNGData(data: testData, theme: .midnightDark, showsItemizedDetails: false)
        )
        #expect(darkPNG.isEmpty == false)
        let darkPNGHeader = [UInt8](darkPNG.prefix(8))
        #expect(darkPNGHeader == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
}
