import Foundation

/// Defines how a receipt item's cost is distributed among participants.
nonisolated enum SplitMode: Equatable, Sendable {
    /// Assigned 100% to a single participant.
    case wholeItem(Participant.ID)
    /// Split equally across the specified set of participants.
    case equal(Set<Participant.ID>)
    /// Split by whole integer percentages (e.g., [A: 50, B: 50]) that must sum to 100.
    case percentage([Participant.ID: Int])
    /// Split proportionally by positive integer shares/portions (e.g., [A: 1, B: 2]).
    case portion([Participant.ID: Int])

    /// All participant identifiers referenced by this split mode.
    var assignedParticipantIDs: Set<Participant.ID> {
        switch self {
        case .wholeItem(let participantID):
            return [participantID]
        case .equal(let participantIDs):
            return participantIDs
        case .percentage(let percentagesByParticipant):
            return Set(percentagesByParticipant.keys)
        case .portion(let portionsByParticipant):
            return Set(portionsByParticipant.keys)
        }
    }

    /// Validates that the split configuration is internally consistent and only references known participants.
    func validate(validParticipants: Set<Participant.ID>) throws(DomainError) {
        switch self {
        case .wholeItem(let participantID):
            guard validParticipants.contains(participantID) else {
                throw .unknownParticipant(participantID)
            }

        case .equal(let participantIDs):
            guard !participantIDs.isEmpty else {
                throw .noParticipantsAssigned
            }
            for participantID in participantIDs {
                guard validParticipants.contains(participantID) else {
                    throw .unknownParticipant(participantID)
                }
            }

        case .percentage(let percentagesByParticipant):
            guard !percentagesByParticipant.isEmpty else {
                throw .noParticipantsAssigned
            }
            var totalPercentage = 0
            for (participantID, percentage) in percentagesByParticipant {
                guard validParticipants.contains(participantID) else {
                    throw .unknownParticipant(participantID)
                }
                guard percentage > 0 else {
                    throw .invalidShareValue(percentage)
                }
                totalPercentage += percentage
            }
            guard totalPercentage == 100 else {
                throw .invalidPercentageTotal(totalPercentage)
            }

        case .portion(let portionsByParticipant):
            guard !portionsByParticipant.isEmpty else {
                throw .noParticipantsAssigned
            }
            for (participantID, portion) in portionsByParticipant {
                guard validParticipants.contains(participantID) else {
                    throw .unknownParticipant(participantID)
                }
                guard portion > 0 else {
                    throw .invalidShareValue(portion)
                }
            }
        }
    }
}
