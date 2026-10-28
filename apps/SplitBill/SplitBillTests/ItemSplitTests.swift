import Foundation
import Testing
@testable import SplitBill

@Suite("Item Split & Largest Remainder Method Tests")
struct ItemSplitTests {

    @Test("Canonical Truth Table: equal splits reconcile to exact item total", arguments: [
        (totalCents: Int64(1_000), expectedShares: [Int64(334), Int64(333), Int64(333)]),
        (totalCents: Int64(1),     expectedShares: [Int64(1), Int64(0)]),
        (totalCents: Int64(0),     expectedShares: [Int64(0), Int64(0), Int64(0)]),
        (totalCents: Int64(1_001), expectedShares: [Int64(334), Int64(334), Int64(333)])
    ])
    func canonicalEqualSplits(totalCents: Int64, expectedShares: [Int64]) throws {
        let participants = try expectedShares.enumerated().map { index, _ in
            try Participant(name: "P\(index)")
        }
        let orderedIDs = participants.map(\.id)

        let item = try ReceiptItem(
            name: "Shared Dish",
            unitPrice: Money(amountInMinorUnits: totalCents, currency: .mxn),
            quantity: 1,
            splitMode: .equal(Set(orderedIDs))
        )

        let allocations = try SplitEngine.allocateItem(item, orderedParticipants: orderedIDs)

        let actualShares = orderedIDs.compactMap { allocations[$0]?.amountInMinorUnits }
        #expect(actualShares == expectedShares)
        #expect(actualShares.reduce(0, +) == totalCents)
    }

    @Test("Canonical Truth Table: percentage split 33%, 33%, 34% on $10.00")
    func canonicalPercentageSplit() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")
        let orderedIDs = [alice.id, bob.id, carlos.id]

        let item = try ReceiptItem(
            name: "Jarra de Sangría",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .percentage([
                alice.id: 33,
                bob.id: 33,
                carlos.id: 34
            ])
        )

        let allocations = try SplitEngine.allocateItem(item, orderedParticipants: orderedIDs)

        #expect(allocations[alice.id] == Money(amountInMinorUnits: 330, currency: .mxn))
        #expect(allocations[bob.id] == Money(amountInMinorUnits: 330, currency: .mxn))
        #expect(allocations[carlos.id] == Money(amountInMinorUnits: 340, currency: .mxn))
    }

    @Test("Largest Remainder prioritizes higher fractional remainder before participant order tie-breaker")
    func largestRemainderPrioritizesHigherFractionFirst() throws {
        // $10.00 (1000 cents) with portions A: 1, B: 3, C: 3 (total weight W = 7)
        // A: 1000 * 1 / 7 = 142 rem 6/7 -> gets 1st leftover cent -> 143
        // B: 1000 * 3 / 7 = 428 rem 4/7 -> ties with C, wins tie-breaker by order -> 429
        // C: 1000 * 3 / 7 = 428 rem 4/7 -> 428
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")
        let orderedIDs = [alice.id, bob.id, carlos.id]

        let item = try ReceiptItem(
            name: "Orden de Tacos",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .portion([
                alice.id: 1,
                bob.id: 3,
                carlos.id: 3
            ])
        )

        let allocations = try SplitEngine.allocateItem(item, orderedParticipants: orderedIDs)

        #expect(allocations[alice.id] == Money(amountInMinorUnits: 143, currency: .mxn))
        #expect(allocations[bob.id] == Money(amountInMinorUnits: 429, currency: .mxn))
        #expect(allocations[carlos.id] == Money(amountInMinorUnits: 428, currency: .mxn))

        let totalAllocated = allocations.values.reduce(Int64(0)) { $0 + $1.amountInMinorUnits }
        #expect(totalAllocated == 1_000)
    }

    @Test("Tie-breaker follows orderedParticipants deterministically when reversed")
    func tieBreakerFollowsOrderedParticipants() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")

        let item = try ReceiptItem(
            name: "Postre",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([alice.id, bob.id, carlos.id])
        )

        // When Carlos is first in the receipt order, Carlos receives the 334 cent share.
        let reversedOrder = [carlos.id, bob.id, alice.id]
        let allocations = try SplitEngine.allocateItem(item, orderedParticipants: reversedOrder)

        #expect(allocations[carlos.id] == Money(amountInMinorUnits: 334, currency: .mxn))
        #expect(allocations[bob.id] == Money(amountInMinorUnits: 333, currency: .mxn))
        #expect(allocations[alice.id] == Money(amountInMinorUnits: 333, currency: .mxn))
    }

    @Test("Allocates wholeItem and multi-quantity items accurately")
    func allocatesWholeItemAndMultiQuantityItem() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")
        let diana = try Participant(name: "Diana")
        let orderedIDs = [alice.id, bob.id, carlos.id, diana.id]

        let singleOwnerItem = try ReceiptItem(
            name: "Café Espresso",
            unitPrice: Money(amountInMinorUnits: 550, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(bob.id)
        )
        let wholeAllocation = try SplitEngine.allocateItem(singleOwnerItem, orderedParticipants: orderedIDs)
        #expect(wholeAllocation.count == 1)
        #expect(wholeAllocation[bob.id] == Money(amountInMinorUnits: 550, currency: .mxn))

        // 3 items at $4.50 = $13.50 (1350 cents) split 4 ways -> 338, 338, 337, 337
        let multiQuantityItem = try ReceiptItem(
            name: "Cerveza Artesanal",
            unitPrice: Money(amountInMinorUnits: 450, currency: .mxn),
            quantity: 3,
            splitMode: .equal(Set(orderedIDs))
        )
        let multiAllocation = try SplitEngine.allocateItem(multiQuantityItem, orderedParticipants: orderedIDs)
        #expect(multiAllocation[alice.id] == Money(amountInMinorUnits: 338, currency: .mxn))
        #expect(multiAllocation[bob.id] == Money(amountInMinorUnits: 338, currency: .mxn))
        #expect(multiAllocation[carlos.id] == Money(amountInMinorUnits: 337, currency: .mxn))
        #expect(multiAllocation[diana.id] == Money(amountInMinorUnits: 337, currency: .mxn))
    }
}
