import Foundation
import Testing
@testable import SplitBill

@Suite("Receipt & End-to-End SplitEngine Tests")
struct ReceiptSplitEngineTests {

    @Test("Calculates complete receipt split and satisfies Master Invariant")
    func calculatesCompleteReceiptSplit() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")
        let participants = [alice, bob, carlos]
        let participantIDs = participants.map(\.id)

        // Item 1: Guacamole $120.00 (12,000 cents) split equally 3 ways -> 4000 each
        let guacamole = try ReceiptItem(
            name: "Guacamole",
            unitPrice: Money(amountInMinorUnits: 12_000, currency: .mxn),
            quantity: 1,
            splitMode: .equal(Set(participantIDs))
        )

        // Item 2: Tacos $150.00 (15,000 cents) for Alice only
        let tacos = try ReceiptItem(
            name: "Orden de Tacos",
            unitPrice: Money(amountInMinorUnits: 15_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )

        // Item 3: Enchiladas $180.00 (18,000 cents) split 50/50 between Bob and Carlos
        let enchiladas = try ReceiptItem(
            name: "Enchiladas",
            unitPrice: Money(amountInMinorUnits: 18_000, currency: .mxn),
            quantity: 1,
            splitMode: .percentage([bob.id: 50, carlos.id: 50])
        )

        // Item 4: Jarra de Agua $35.00 (3,500 cents) portion 1:2 between Alice and Bob -> A: 1167, B: 2333
        let agua = try ReceiptItem(
            name: "Jarra de Agua",
            unitPrice: Money(amountInMinorUnits: 3_500, currency: .mxn),
            quantity: 1,
            splitMode: .portion([alice.id: 1, bob.id: 2])
        )

        // Subtotal = 12,000 + 15,000 + 18,000 + 3,500 = 48,500 cents ($485.00 MXN)
        // Alice subtotal: 4,000 + 15,000 + 1,167 = 20,167 cents ($201.67)
        // Bob subtotal:   4,000 +  9,000 + 2,333 = 15,333 cents ($153.33)
        // Carlos subtotal:4,000 +  9,000        = 13,000 cents ($130.00)

        // Tax (16% IVA) = $77.60 MXN (7,760 cents)
        let tax = Money(amountInMinorUnits: 7_760, currency: .mxn)
        // Tip (10% Propina) = $48.50 MXN (4,850 cents)
        let tip = Money(amountInMinorUnits: 4_850, currency: .mxn)

        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [guacamole, tacos, enchiladas, agua],
            tax: tax,
            tip: tip
        )

        #expect(receipt.itemsSubtotal == Money(amountInMinorUnits: 48_500, currency: .mxn))
        // Grand total: 48,500 + 7,760 + 4,850 = 61,110 cents ($611.10 MXN)
        #expect(receipt.total == Money(amountInMinorUnits: 61_110, currency: .mxn))

        let result = try SplitEngine.calculateSplit(for: receipt)

        // Master Allocation Invariant
        #expect(result.totalAllocated == receipt.total)

        let aliceSummary = try #require(result.summariesByParticipant[alice.id])
        let bobSummary = try #require(result.summariesByParticipant[bob.id])
        let carlosSummary = try #require(result.summariesByParticipant[carlos.id])

        #expect(aliceSummary.itemsSubtotal == Money(amountInMinorUnits: 20_167, currency: .mxn))
        #expect(bobSummary.itemsSubtotal == Money(amountInMinorUnits: 15_333, currency: .mxn))
        #expect(carlosSummary.itemsSubtotal == Money(amountInMinorUnits: 13_000, currency: .mxn))

        // Check tax conservation
        let totalTaxAllocated = aliceSummary.taxAllocated.amountInMinorUnits
            + bobSummary.taxAllocated.amountInMinorUnits
            + carlosSummary.taxAllocated.amountInMinorUnits
        #expect(totalTaxAllocated == tax.amountInMinorUnits)

        // Check tip conservation
        let totalTipAllocated = aliceSummary.tipAllocated.amountInMinorUnits
            + bobSummary.tipAllocated.amountInMinorUnits
            + carlosSummary.tipAllocated.amountInMinorUnits
        #expect(totalTipAllocated == tip.amountInMinorUnits)

        // Check participant total sums
        let sumOfParticipantTotals = aliceSummary.total.amountInMinorUnits
            + bobSummary.total.amountInMinorUnits
            + carlosSummary.total.amountInMinorUnits
        #expect(sumOfParticipantTotals == receipt.total.amountInMinorUnits)

        // Check item allocations structure
        #expect(result.itemAllocations[guacamole.id]?[alice.id] == Money(amountInMinorUnits: 4_000, currency: .mxn))
        #expect(result.itemAllocations[guacamole.id]?[bob.id] == Money(amountInMinorUnits: 4_000, currency: .mxn))
        #expect(result.itemAllocations[guacamole.id]?[carlos.id] == Money(amountInMinorUnits: 4_000, currency: .mxn))
        #expect(result.itemAllocations[tacos.id]?[alice.id] == Money(amountInMinorUnits: 15_000, currency: .mxn))
        #expect(result.itemAllocations[tacos.id]?[bob.id] == nil)
    }

    @Test("Unallocated participant owes zero subtotal, tax, and tip")
    func unallocatedParticipantOwesZero() throws {
        let alice = try Participant(name: "Alice")
        let bystander = try Participant(name: "Bystander")
        let participants = [alice, bystander]

        let item = try ReceiptItem(
            name: "Platillo",
            unitPrice: Money(amountInMinorUnits: 2_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )

        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [item],
            tax: Money(amountInMinorUnits: 320, currency: .mxn),
            tip: Money(amountInMinorUnits: 200, currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        let bystanderSummary = try #require(result.summariesByParticipant[bystander.id])
        #expect(bystanderSummary.itemsSubtotal == Money.zero(currency: .mxn))
        #expect(bystanderSummary.taxAllocated == Money.zero(currency: .mxn))
        #expect(bystanderSummary.tipAllocated == Money.zero(currency: .mxn))
        #expect(bystanderSummary.total == Money.zero(currency: .mxn))

        let aliceSummary = try #require(result.summariesByParticipant[alice.id])
        #expect(aliceSummary.total == receipt.total)
        #expect(result.totalAllocated == receipt.total)
    }

    @Test("Zero-item receipt splits flat tax and tip equally across participants")
    func zeroItemReceiptSplitsTaxAndTipEqually() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let participants = [alice, bob]

        let flatCoverTax = Money(amountInMinorUnits: 1_000, currency: .mxn)
        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [],
            tax: flatCoverTax,
            tip: Money.zero(currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        #expect(result.summariesByParticipant[alice.id]?.total == Money(amountInMinorUnits: 500, currency: .mxn))
        #expect(result.summariesByParticipant[bob.id]?.total == Money(amountInMinorUnits: 500, currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
    }

    // MARK: - Proportional Tax & Tip Rounding Dynamics

    @Test("Proportional tax and tip allocate odd cents independently by largest remainder")
    func proportionalTaxAndTipAllocateOddCentsByLargestRemainder() throws {
        // Alice consumes $20.00 (2,000 cents), Bob consumes $10.00 (1,000 cents). Ratio = 2:1 (Total W = 3,000).
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let participants = [alice, bob]

        let steak = try ReceiptItem(
            name: "Corte Ribeye",
            unitPrice: Money(amountInMinorUnits: 2_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )
        let burger = try ReceiptItem(
            name: "Hamburguesa",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(bob.id)
        )

        // Tax $1.00 (100 cents):
        // Alice: 100 * 2000 / 3000 = 66 rem 2000 (fraction 2/3) -> gets 1st leftover cent -> 67 cents
        // Bob:   100 * 1000 / 3000 = 33 rem 1000 (fraction 1/3) -> 33 cents
        let tax = Money(amountInMinorUnits: 100, currency: .mxn)

        // Tip $0.50 (50 cents):
        // Alice: 50 * 2000 / 3000 = 33 rem 1000 (fraction 1/3) -> 33 cents
        // Bob:   50 * 1000 / 3000 = 16 rem 2000 (fraction 2/3) -> gets 1st leftover cent -> 17 cents
        let tip = Money(amountInMinorUnits: 50, currency: .mxn)

        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [steak, burger],
            tax: tax,
            tip: tip
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        let aliceSummary = try #require(result.summariesByParticipant[alice.id])
        let bobSummary = try #require(result.summariesByParticipant[bob.id])

        #expect(aliceSummary.taxAllocated == Money(amountInMinorUnits: 67, currency: .mxn))
        #expect(bobSummary.taxAllocated == Money(amountInMinorUnits: 33, currency: .mxn))

        #expect(aliceSummary.tipAllocated == Money(amountInMinorUnits: 33, currency: .mxn))
        #expect(bobSummary.tipAllocated == Money(amountInMinorUnits: 17, currency: .mxn))

        #expect(aliceSummary.total == Money(amountInMinorUnits: 2_100, currency: .mxn))
        #expect(bobSummary.total == Money(amountInMinorUnits: 1_050, currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
    }

    @Test("Deterministic tie-breaker awards odd tax cent to first participant in receipt order", arguments: [
        false,
        true
    ])
    func deterministicTieBreakerForProportionalTax(isReversed: Bool) throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let orderedParticipants = isReversed ? [bob, alice] : [alice, bob]

        let pizza1 = try ReceiptItem(
            name: "Pizza Alice",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )
        let pizza2 = try ReceiptItem(
            name: "Pizza Bob",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(bob.id)
        )

        // Tax is $0.01 (1 cent). Both Alice and Bob have equal subtotal ($10.00) and remainder fraction (1/2).
        let receipt = try Receipt(
            currency: .mxn,
            participants: orderedParticipants,
            items: [pizza1, pizza2],
            tax: Money(amountInMinorUnits: 1, currency: .mxn),
            tip: Money.zero(currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        let firstID = orderedParticipants[0].id
        let secondID = orderedParticipants[1].id

        #expect(result.summariesByParticipant[firstID]?.taxAllocated == Money(amountInMinorUnits: 1, currency: .mxn))
        #expect(result.summariesByParticipant[secondID]?.taxAllocated == Money.zero(currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
    }

    // MARK: - Zero Amounts & Boundary Cases

    @Test("Receipt with zero tax and zero tip allocates exact item subtotals")
    func receiptWithZeroTaxAndTipAllocatesExactSubtotals() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")

        let taco = try ReceiptItem(
            name: "Taco",
            unitPrice: Money(amountInMinorUnits: 500, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )

        let receipt = try Receipt(
            currency: .mxn,
            participants: [alice, bob],
            items: [taco],
            tax: nil,
            tip: nil
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        #expect(result.summariesByParticipant[alice.id]?.total == Money(amountInMinorUnits: 500, currency: .mxn))
        #expect(result.summariesByParticipant[bob.id]?.total == Money.zero(currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
        #expect(receipt.total == receipt.itemsSubtotal)
    }

    @Test("Promotional zero-subtotal items fall back to equal tax and tip split across all participants")
    func promotionalZeroSubtotalItemsSplitTaxEqually() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")

        let freeDrink1 = try ReceiptItem(
            name: "Bebida Cortesía 1",
            unitPrice: Money.zero(currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )
        let freeDrink2 = try ReceiptItem(
            name: "Bebida Cortesía 2",
            unitPrice: Money.zero(currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(bob.id)
        )

        // Both items cost $0.00, but receipt has a cover fee tax of $1.00 (100 cents) and $0.50 tip (50 cents).
        let receipt = try Receipt(
            currency: .mxn,
            participants: [alice, bob],
            items: [freeDrink1, freeDrink2],
            tax: Money(amountInMinorUnits: 100, currency: .mxn),
            tip: Money(amountInMinorUnits: 50, currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        #expect(result.summariesByParticipant[alice.id]?.taxAllocated == Money(amountInMinorUnits: 50, currency: .mxn))
        #expect(result.summariesByParticipant[bob.id]?.taxAllocated == Money(amountInMinorUnits: 50, currency: .mxn))
        #expect(result.summariesByParticipant[alice.id]?.tipAllocated == Money(amountInMinorUnits: 25, currency: .mxn))
        #expect(result.summariesByParticipant[bob.id]?.tipAllocated == Money(amountInMinorUnits: 25, currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
    }

    @Test("Multiple bystanders owe zero while consuming participants absorb 100% of tax and tip")
    func multipleBystandersOweZero() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let bystander1 = try Participant(name: "Bystander 1")
        let bystander2 = try Participant(name: "Bystander 2")
        let participants = [alice, bob, bystander1, bystander2]

        let item1 = try ReceiptItem(
            name: "Plato Fuerte A",
            unitPrice: Money(amountInMinorUnits: 4_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(alice.id)
        )
        let item2 = try ReceiptItem(
            name: "Plato Fuerte B",
            unitPrice: Money(amountInMinorUnits: 6_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(bob.id)
        )

        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [item1, item2],
            tax: Money(amountInMinorUnits: 1_000, currency: .mxn),
            tip: Money(amountInMinorUnits: 500, currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        #expect(result.summariesByParticipant[bystander1.id]?.total == Money.zero(currency: .mxn))
        #expect(result.summariesByParticipant[bystander2.id]?.total == Money.zero(currency: .mxn))
        #expect(result.summariesByParticipant[alice.id]?.taxAllocated == Money(amountInMinorUnits: 400, currency: .mxn))
        #expect(result.summariesByParticipant[bob.id]?.taxAllocated == Money(amountInMinorUnits: 600, currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
    }

    // MARK: - Domain Invariants & Validations

    @Test("Receipt deduplicates repeated participants preserving first-seen canonical order")
    func receiptDeduplicatesRepeatedParticipants() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")

        let item = try ReceiptItem(
            name: "Botana",
            unitPrice: Money(amountInMinorUnits: 1_000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([alice.id, bob.id])
        )

        let receipt = try Receipt(
            currency: .mxn,
            participants: [alice, bob, alice],
            items: [item]
        )

        #expect(receipt.participants.count == 2)
        #expect(receipt.participants[0].id == alice.id)
        #expect(receipt.participants[1].id == bob.id)

        let result = try SplitEngine.calculateSplit(for: receipt)
        #expect(result.summariesByParticipant.count == 2)
        #expect(result.totalAllocated == receipt.total)
    }

    @Test("Minimal 1-cent total receipt satisfies Master Conservation Invariant")
    func minimalOneCentReceiptConservesTotal() throws {
        let alice = try Participant(name: "Alice")
        let bob = try Participant(name: "Bob")
        let carlos = try Participant(name: "Carlos")
        let participants = [alice, bob, carlos]

        let centItem = try ReceiptItem(
            name: "Chicle",
            unitPrice: Money(amountInMinorUnits: 1, currency: .mxn),
            quantity: 1,
            splitMode: .equal(Set(participants.map(\.id)))
        )

        let receipt = try Receipt(
            currency: .mxn,
            participants: participants,
            items: [centItem],
            tax: Money(amountInMinorUnits: 1, currency: .mxn),
            tip: Money(amountInMinorUnits: 1, currency: .mxn)
        )

        let result = try SplitEngine.calculateSplit(for: receipt)

        #expect(receipt.total == Money(amountInMinorUnits: 3, currency: .mxn))
        #expect(result.totalAllocated == receipt.total)
        let sumOfTotals = result.summariesByParticipant.values.reduce(Int64(0)) { $0 + $1.total.amountInMinorUnits }
        #expect(sumOfTotals == 3)
    }

    @Test("Receipt rejects negative tax, negative tip, currency mismatch on tip or item, and unknown participant")
    func rejectsAllInvalidReceiptInputs() throws {
        let alice = try Participant(name: "Alice")
        let stranger = try Participant(name: "Stranger")

        // 1. Negative tax
        #expect(throws: DomainError.negativeAmount(-100)) {
            try Receipt(
                currency: .mxn,
                participants: [alice],
                tax: Money(amountInMinorUnits: -100, currency: .mxn)
            )
        }

        // 2. Negative tip
        #expect(throws: DomainError.negativeAmount(-50)) {
            try Receipt(
                currency: .mxn,
                participants: [alice],
                tip: Money(amountInMinorUnits: -50, currency: .mxn)
            )
        }

        // 3. Tip currency mismatch
        #expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd)) {
            try Receipt(
                currency: .mxn,
                participants: [alice],
                tip: Money(amountInMinorUnits: 100, currency: .usd)
            )
        }

        // 4. Item currency mismatch
        let usdItem = try ReceiptItem(
            name: "Coffee",
            unitPrice: Money(amountInMinorUnits: 400, currency: .usd),
            splitMode: .wholeItem(alice.id)
        )
        #expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd)) {
            try Receipt(
                currency: .mxn,
                participants: [alice],
                items: [usdItem]
            )
        }

        // 5. Item referencing participant not in receipt
        let strangerItem = try ReceiptItem(
            name: "Postre",
            unitPrice: Money(amountInMinorUnits: 800, currency: .mxn),
            splitMode: .wholeItem(stranger.id)
        )
        #expect(throws: DomainError.unknownParticipant(stranger.id)) {
            try Receipt(
                currency: .mxn,
                participants: [alice],
                items: [strangerItem]
            )
        }
    }
}
