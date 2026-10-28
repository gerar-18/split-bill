import Foundation

/// Pure, deterministic calculation engine for allocating monetary amounts and receipt items.
nonisolated enum SplitEngine {

    /// Allocates a monetary amount across a subset of weighted participants using Hamilton's Largest Remainder Method.
    ///
    /// - Parameters:
    ///   - amount: The non-negative total `Money` amount to distribute.
    ///   - orderedParticipants: The canonical participant order used as a deterministic tie-breaker when remainders are equal.
    ///   - weights: Positive integer weights keyed by `Participant.ID`.
    /// - Returns: A dictionary mapping each assigned `Participant.ID` to their exact allocated `Money` share,
    ///            guaranteed to sum exactly to `amount`.
    static func allocate(
        amount: Money,
        orderedParticipants: [Participant.ID],
        weights: [Participant.ID: Int64]
    ) throws(DomainError) -> [Participant.ID: Money] {
        guard amount.amountInMinorUnits >= 0 else {
            throw .negativeAmount(amount.amountInMinorUnits)
        }
        guard !orderedParticipants.isEmpty else {
            throw .noParticipantsInReceipt
        }
        guard !weights.isEmpty else {
            throw .noParticipantsAssigned
        }

        // Preserve canonical order while deduplicating any repeated participant IDs.
        var seen = Set<Participant.ID>()
        var canonicalOrder: [Participant.ID] = []
        for participantID in orderedParticipants {
            if seen.insert(participantID).inserted {
                canonicalOrder.append(participantID)
            }
        }

        // Validate that every weighted participant exists in canonicalOrder and has a positive weight.
        for (participantID, weight) in weights {
            guard seen.contains(participantID) else {
                throw .unknownParticipant(participantID)
            }
            guard weight > 0 else {
                let clampedWeight = Int(clamping: weight)
                throw .invalidShareValue(clampedWeight)
            }
        }

        // Filter to assigned participants in canonical order.
        let activeParticipants = canonicalOrder.filter { weights[$0] != nil }
        let totalWeight = activeParticipants.reduce(Int64(0)) { partial, id in
            partial + (weights[id] ?? 0)
        }

        struct ShareEntry {
            let participantID: Participant.ID
            let orderIndex: Int
            var allocatedMinorUnits: Int64
            let remainderNumerator: Int64
        }

        var entries: [ShareEntry] = []
        entries.reserveCapacity(activeParticipants.count)

        var sumOfBaseQuotas: Int64 = 0
        let totalMinorUnits = amount.amountInMinorUnits

        for (index, participantID) in activeParticipants.enumerated() {
            let weight = weights[participantID] ?? 0
            let fullProduct = totalMinorUnits.multipliedFullWidth(by: weight)
            let (quotient, remainder) = totalWeight.dividingFullWidth(fullProduct)

            sumOfBaseQuotas += quotient
            entries.append(
                ShareEntry(
                    participantID: participantID,
                    orderIndex: index,
                    allocatedMinorUnits: quotient,
                    remainderNumerator: remainder
                )
            )
        }

        let leftoverCents = Int(totalMinorUnits - sumOfBaseQuotas)

        if leftoverCents > 0 {
            // Sort indices by largest exact remainder descending, then by canonical participant order ascending.
            let rankedIndices = entries.indices.sorted { lhs, rhs in
                if entries[lhs].remainderNumerator != entries[rhs].remainderNumerator {
                    return entries[lhs].remainderNumerator > entries[rhs].remainderNumerator
                }
                return entries[lhs].orderIndex < entries[rhs].orderIndex
            }

            for rankIndex in 0..<leftoverCents {
                let targetEntryIndex = rankedIndices[rankIndex]
                entries[targetEntryIndex].allocatedMinorUnits += 1
            }
        }

        var result: [Participant.ID: Money] = [:]
        result.reserveCapacity(entries.count)
        for entry in entries {
            result[entry.participantID] = Money(
                amountInMinorUnits: entry.allocatedMinorUnits,
                currency: amount.currency
            )
        }

        return result
    }

    /// Allocates a single `ReceiptItem`'s `lineTotal` across its assigned participants according to its `SplitMode`.
    ///
    /// - Parameters:
    ///   - item: The receipt item to split.
    ///   - orderedParticipants: The ordered list of participant IDs belonging to the receipt.
    /// - Returns: Exact `Money` allocations keyed by `Participant.ID`, summing to `item.lineTotal`.
    static func allocateItem(
        _ item: ReceiptItem,
        orderedParticipants: [Participant.ID]
    ) throws(DomainError) -> [Participant.ID: Money] {
        guard !orderedParticipants.isEmpty else {
            throw .noParticipantsInReceipt
        }

        let validSet = Set(orderedParticipants)
        try item.splitMode.validate(validParticipants: validSet)

        let weights: [Participant.ID: Int64]
        switch item.splitMode {
        case .wholeItem(let participantID):
            weights = [participantID: 1]

        case .equal(let participantIDs):
            var equalWeights: [Participant.ID: Int64] = [:]
            equalWeights.reserveCapacity(participantIDs.count)
            for id in participantIDs {
                equalWeights[id] = 1
            }
            weights = equalWeights

        case .percentage(let percentagesByParticipant):
            weights = percentagesByParticipant.mapValues { Int64($0) }

        case .portion(let portionsByParticipant):
            weights = portionsByParticipant.mapValues { Int64($0) }
        }

        return try allocate(
            amount: item.lineTotal,
            orderedParticipants: orderedParticipants,
            weights: weights
        )
    }
}
