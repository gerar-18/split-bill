import Foundation
import Testing
@testable import SplitBill

@Suite("Shared Collaboration Domain Models")
struct SharedCollaborationDomainTests {

    @Test("ShareCode normalizes whitespace and lowercase valid Crockford Base32 strings")
    func shareCodeValidNormalization() throws {
        let code = try ShareCode(rawValue: "  a1b2c3d4 \n")
        #expect(code.value == "A1B2C3D4")
    }

    @Test("ShareCode rejects invalid length and excluded ambiguous letters", arguments: [
        "",
        "ABC123",       // too short (6)
        "ABC123456",    // too long (9)
        "ABCD123I",     // excluded 'I'
        "ABCD123L",     // excluded 'L'
        "ABCD123O",     // excluded 'O'
        "ABCD123U",     // excluded 'U'
        "ABCD-123"      // invalid symbol
    ])
    func shareCodeRejectsInvalidInputs(rawInput: String) {
        #expect(throws: DomainError.invalidShareCode) {
            _ = try ShareCode(rawValue: rawInput)
        }
    }

    @Test("SharedItemClaimState maps 0, 1, and multiple claimants additively")
    func additiveClaimStateTransitions() throws {
        let alice = UUID()
        let bob = UUID()
        let validSet: Set<UUID> = [alice, bob]

        let zeroState = try SharedItemClaimState.fromClaimants([], validParticipants: validSet)
        #expect(zeroState == .unassigned)

        let oneState = try SharedItemClaimState.fromClaimants([alice], validParticipants: validSet)
        #expect(oneState == .assigned(.wholeItem(alice)))

        let multiState = try SharedItemClaimState.fromClaimants([alice, bob, alice], validParticipants: validSet)
        #expect(multiState == .assigned(.equal([alice, bob])))
    }

    @Test("SharedItemClaimState rejects unknown participant ID")
    func claimStateRejectsUnknownParticipant() {
        let known = UUID()
        let stranger = UUID()

        #expect(throws: DomainError.unknownParticipant(stranger)) {
            _ = try SharedItemClaimState.fromClaimants([known, stranger], validParticipants: [known])
        }
    }

    @Test("CollaborationSplitPreview preserves exact penny conservation across claimed and unclaimed items")
    func collaborationSplitPreviewConservation() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let charlie = try Participant(name: "Charlie")

        let item1 = try SharedReceiptLineItem(
            id: UUID(),
            name: "Nachos Compartidos",
            unitPrice: Money(amountInMinorUnits: 1000, currency: .mxn), // $10.00 across 3 -> 334, 333, 333
            quantity: 1,
            claimantIDs: [alice.id, bob.id, charlie.id]
        )
        let item2 = try SharedReceiptLineItem(
            id: UUID(),
            name: "Taco Individual",
            unitPrice: Money(amountInMinorUnits: 450, currency: .mxn), // $4.50
            quantity: 2,                                              // $9.00 unclaimed
            claimantIDs: []
        )
        let item3 = try SharedReceiptLineItem(
            id: UUID(),
            name: "Agua Mineral",
            unitPrice: Money(amountInMinorUnits: 350, currency: .mxn), // $3.50 to Bob
            quantity: 1,
            claimantIDs: [bob.id]
        )

        let tax = Money(amountInMinorUnits: 200, currency: .mxn)
        let tip = Money(amountInMinorUnits: 101, currency: .mxn)

        let preview = try CollaborationSplitPreview.compute(
            receiptID: UUID(),
            currency: .mxn,
            participants: [alice, bob, charlie],
            items: [item1, item2, item3],
            tax: tax,
            tip: tip
        )

        #expect(preview.unclaimedItemIDs == [item2.id])
        #expect(preview.unclaimedSubtotal.amountInMinorUnits == 900)
        #expect(preview.assignedItemsSubtotal.amountInMinorUnits == 1350)
        #expect(preview.grandTotal.amountInMinorUnits == 2551)

        // Master conservation invariant: allocated + unclaimed == grandTotal
        #expect(
            preview.splitResult.totalAllocated.amountInMinorUnits + preview.unclaimedSubtotal.amountInMinorUnits
            == preview.grandTotal.amountInMinorUnits
        )
    }

    @Test("CollaborationSplitPreview handles 100% unclaimed items cleanly without losing tax or tip")
    func collaborationSplitPreviewAllUnclaimed() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")

        let unclaimed = try SharedReceiptLineItem(
            id: UUID(),
            name: "Pizza",
            unitPrice: Money(amountInMinorUnits: 1200, currency: .usd),
            quantity: 1,
            claimantIDs: []
        )

        let preview = try CollaborationSplitPreview.compute(
            receiptID: UUID(),
            currency: .usd,
            participants: [alice, bob],
            items: [unclaimed],
            tax: Money(amountInMinorUnits: 100, currency: .usd),
            tip: Money(amountInMinorUnits: 1, currency: .usd)
        )

        #expect(preview.unclaimedSubtotal.amountInMinorUnits == 1200)
        #expect(preview.splitResult.totalAllocated.amountInMinorUnits == 101)
        #expect(
            preview.splitResult.totalAllocated.amountInMinorUnits + preview.unclaimedSubtotal.amountInMinorUnits
            == preview.grandTotal.amountInMinorUnits
        )
    }
}
