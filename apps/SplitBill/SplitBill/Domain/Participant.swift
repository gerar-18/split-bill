import Foundation

/// A person participating in a receipt split.
nonisolated struct Participant: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String

    /// Creates a validated participant with a non-empty trimmed name.
    init(id: UUID = UUID(), name: String) throws(DomainError) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .emptyParticipantName
        }
        self.id = id
        self.name = trimmedName
    }
}
