import Foundation

/// Typed domain errors for M1 receipt and money operations.
nonisolated enum DomainError: Error, Equatable, Sendable {
    case emptyParticipantName
    case emptyItemName
    case invalidQuantity(Int)
    case negativeAmount(Int64)
    case currencyMismatch(expected: Currency, actual: Currency)
    case noParticipantsInReceipt
    case noParticipantsAssigned
    case unknownParticipant(UUID)
    case invalidPercentageTotal(Int)
    case invalidShareValue(Int)
    case invalidShareCode
    case sessionExpired
    case versionConflict
}
