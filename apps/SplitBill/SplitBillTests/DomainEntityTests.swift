import Foundation
import Testing
@testable import SplitBill

@Suite("Participant, SplitMode & ReceiptItem Domain Tests")
struct DomainEntityTests {

    // MARK: - Participant Tests

    @Test("Creates Participant and trims surrounding whitespace")
    func createsParticipantAndTrimsWhitespace() throws {
        let participant = try Participant(name: "  Gerardo  \n")
        #expect(participant.name == "Gerardo")
    }

    @Test("Rejects empty or whitespace-only Participant name", arguments: [
        "",
        "   ",
        "\n\t "
    ])
    func rejectsEmptyParticipantName(invalidName: String) {
        #expect(throws: DomainError.emptyParticipantName) {
            try Participant(name: invalidName)
        }
    }

    // MARK: - SplitMode Validation Tests

    @Test("Validates all 4 SplitMode cases when participants and shares are valid")
    func validatesValidSplitModes() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let validIDs: Set<Participant.ID> = [alice.id, bob.id]

        let whole = SplitMode.wholeItem(alice.id)
        try whole.validate(validParticipants: validIDs)
        #expect(whole.assignedParticipantIDs == [alice.id])

        let equal = SplitMode.equal([alice.id, bob.id])
        try equal.validate(validParticipants: validIDs)
        #expect(equal.assignedParticipantIDs == [alice.id, bob.id])

        let percentage = SplitMode.percentage([alice.id: 60, bob.id: 40])
        try percentage.validate(validParticipants: validIDs)
        #expect(percentage.assignedParticipantIDs == [alice.id, bob.id])

        let portion = SplitMode.portion([alice.id: 1, bob.id: 3])
        try portion.validate(validParticipants: validIDs)
        #expect(portion.assignedParticipantIDs == [alice.id, bob.id])
    }

    @Test("Rejects SplitMode with empty participant assignments")
    func rejectsEmptyParticipantAssignments() throws {
        let alice = try Participant(name: "Alice")
        let validIDs: Set<Participant.ID> = [alice.id]

        #expect(throws: DomainError.noParticipantsAssigned) {
            try SplitMode.equal([]).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.noParticipantsAssigned) {
            try SplitMode.percentage([:]).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.noParticipantsAssigned) {
            try SplitMode.portion([:]).validate(validParticipants: validIDs)
        }
    }

    @Test("Rejects SplitMode referencing an unknown participant ID")
    func rejectsUnknownParticipantInSplitMode() throws {
        let alice = try Participant(name: "Alice")
        let stranger = try Participant(name: "Stranger")
        let validIDs: Set<Participant.ID> = [alice.id]

        #expect(throws: DomainError.unknownParticipant(stranger.id)) {
            try SplitMode.wholeItem(stranger.id).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.unknownParticipant(stranger.id)) {
            try SplitMode.equal([stranger.id]).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.unknownParticipant(stranger.id)) {
            try SplitMode.percentage([stranger.id: 100]).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.unknownParticipant(stranger.id)) {
            try SplitMode.portion([stranger.id: 1]).validate(validParticipants: validIDs)
        }
    }

    @Test("Rejects percentage SplitMode when total does not equal 100", arguments: [
        99,
        101,
        50
    ])
    func rejectsInvalidPercentageTotal(invalidTotal: Int) throws {
        let alice = try Participant(name: "Alice")
        let validIDs: Set<Participant.ID> = [alice.id]

        #expect(throws: DomainError.invalidPercentageTotal(invalidTotal)) {
            try SplitMode.percentage([alice.id: invalidTotal]).validate(validParticipants: validIDs)
        }
    }

    @Test("Rejects non-positive share values in percentage and portion modes", arguments: [
        0,
        -10
    ])
    func rejectsNonPositiveShareValues(invalidShare: Int) throws {
        let alice = try Participant(name: "Alice")
        let validIDs: Set<Participant.ID> = [alice.id]

        #expect(throws: DomainError.invalidShareValue(invalidShare)) {
            try SplitMode.percentage([alice.id: invalidShare]).validate(validParticipants: validIDs)
        }
        #expect(throws: DomainError.invalidShareValue(invalidShare)) {
            try SplitMode.portion([alice.id: invalidShare]).validate(validParticipants: validIDs)
        }
    }

    // MARK: - ReceiptItem Tests

    @Test("Creates ReceiptItem with quantity > 1 and computes exact lineTotal")
    func createsReceiptItemAndComputesLineTotal() throws {
        let alice = try Participant(name: "Alice")
        let unitPrice = try Money.nonNegative(minorUnits: 450, currency: .mxn)

        let item = try ReceiptItem(
            name: "  Taco al Pastor ",
            unitPrice: unitPrice,
            quantity: 3,
            splitMode: .wholeItem(alice.id)
        )

        #expect(item.name == "Taco al Pastor")
        #expect(item.quantity == 3)
        #expect(item.unitPrice == unitPrice)
        #expect(item.lineTotal == Money(amountInMinorUnits: 1_350, currency: .mxn))
    }

    @Test("Supports zero-value items and duplicate item names with distinct UUIDs")
    func supportsZeroValueAndDuplicateItemNames() throws {
        let alice = try Participant(name: "Alice")
        let zeroPrice = Money.zero(currency: .mxn)

        let item1 = try ReceiptItem(
            name: "Cortesía",
            unitPrice: zeroPrice,
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )
        let item2 = try ReceiptItem(
            name: "Cortesía",
            unitPrice: zeroPrice,
            quantity: 2,
            splitMode: .wholeItem(alice.id)
        )

        #expect(item1.name == item2.name)
        #expect(item1.id != item2.id)
        #expect(item1.lineTotal == Money.zero(currency: .mxn))
        #expect(item2.lineTotal == Money.zero(currency: .mxn))
    }

    @Test("Rejects ReceiptItem with empty name, negative price, or quantity < 1")
    func rejectsInvalidReceiptItemInputs() throws {
        let alice = try Participant(name: "Alice")
        let validPrice = Money(amountInMinorUnits: 1_000, currency: .mxn)

        #expect(throws: DomainError.emptyItemName) {
            try ReceiptItem(
                name: "   ",
                unitPrice: validPrice,
                quantity: 1,
                splitMode: .wholeItem(alice.id)
            )
        }

        let negativePrice = Money(amountInMinorUnits: -500, currency: .mxn)
        #expect(throws: DomainError.negativeAmount(-500)) {
            try ReceiptItem(
                name: "Refresco",
                unitPrice: negativePrice,
                quantity: 1,
                splitMode: .wholeItem(alice.id)
            )
        }

        #expect(throws: DomainError.invalidQuantity(0)) {
            try ReceiptItem(
                name: "Refresco",
                unitPrice: validPrice,
                quantity: 0,
                splitMode: .wholeItem(alice.id)
            )
        }
    }
}
