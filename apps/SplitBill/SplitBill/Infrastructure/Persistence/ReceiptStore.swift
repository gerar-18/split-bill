import Foundation
import SwiftData

/// Storage boundary contract for persisting and retrieving receipts.
@MainActor
protocol ReceiptPersistenceStore: Sendable {
    func fetchAll() throws -> [ReceiptSnapshot]
    func fetch(id: UUID) throws -> ReceiptSnapshot?
    func save(_ snapshot: ReceiptSnapshot) throws
    func delete(id: UUID) throws
}

/// SwiftData implementation of `ReceiptPersistenceStore`.
@MainActor
final class SwiftDataReceiptStore: ReceiptPersistenceStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// Creates an isolated in-memory store suitable for unit tests and SwiftUI Previews.
    static func inMemory() throws -> SwiftDataReceiptStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredReceipt.self, configurations: configuration)
        return SwiftDataReceiptStore(container: container)
    }

    /// Creates a persistent on-disk store for production application execution.
    /// Gracefully falls back to an in-memory store if disk storage initialization fails.
    static func live() -> SwiftDataReceiptStore {
        if let container = try? ModelContainer(for: StoredReceipt.self) {
            return SwiftDataReceiptStore(container: container)
        }
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let fallback = try? ModelContainer(for: StoredReceipt.self, configurations: configuration) else {
            fatalError("Failed to initialize SwiftData ModelContainer")
        }
        return SwiftDataReceiptStore(container: fallback)
    }

    func fetchAll() throws -> [ReceiptSnapshot] {
        let descriptor = FetchDescriptor<StoredReceipt>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        return try records.map { try $0.toSnapshot() }
    }

    func fetch(id: UUID) throws -> ReceiptSnapshot? {
        let targetID = id
        var descriptor = FetchDescriptor<StoredReceipt>(
            predicate: #Predicate { $0.receiptID == targetID }
        )
        descriptor.fetchLimit = 1
        let records = try context.fetch(descriptor)
        return try records.first?.toSnapshot()
    }

    func save(_ snapshot: ReceiptSnapshot) throws {
        let targetID = snapshot.id
        var descriptor = FetchDescriptor<StoredReceipt>(
            predicate: #Predicate { $0.receiptID == targetID }
        )
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor).first

        if let existing {
            try existing.update(from: snapshot)
        } else {
            let record = try StoredReceipt(from: snapshot)
            context.insert(record)
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<StoredReceipt>(
            predicate: #Predicate { $0.receiptID == targetID }
        )
        let records = try context.fetch(descriptor)
        for record in records {
            context.delete(record)
        }
        try context.save()
    }
}
