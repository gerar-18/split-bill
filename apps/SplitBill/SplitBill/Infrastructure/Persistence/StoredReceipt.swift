import Foundation
import SwiftData

/// SwiftData persistent entity for receipts.
///
/// To prevent SQLite relations from shuffling participant array order and to ensure
/// lossless serialization across all 4 `SplitMode` cases, participants and items are
/// serialized inside `payloadData` as `ReceiptPayloadDTO`.
///
/// Large receipt imagery is stored externally via `@Attribute(.externalStorage)` to prevent
/// SQLite database bloat while maintaining seamless object-relational mapping.
@Model
final class StoredReceipt {
    @Attribute(.unique) var receiptID: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var currencyCode: String
    var currencyScale: Int
    var taxMinorUnits: Int64
    var tipModeRaw: String
    var tipPercentage: Int?
    var customTipMinorUnits: Int64?
    var payloadData: Data
    @Attribute(.externalStorage) var receiptImageData: Data?
    var ocrRawText: String?

    init(
        receiptID: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        currencyCode: String,
        currencyScale: Int,
        taxMinorUnits: Int64,
        tipModeRaw: String,
        tipPercentage: Int?,
        customTipMinorUnits: Int64?,
        payloadData: Data,
        receiptImageData: Data? = nil,
        ocrRawText: String? = nil
    ) {
        self.receiptID = receiptID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currencyCode = currencyCode
        self.currencyScale = currencyScale
        self.taxMinorUnits = taxMinorUnits
        self.tipModeRaw = tipModeRaw
        self.tipPercentage = tipPercentage
        self.customTipMinorUnits = customTipMinorUnits
        self.payloadData = payloadData
        self.receiptImageData = receiptImageData
        self.ocrRawText = ocrRawText
    }

    convenience init(from snapshot: ReceiptSnapshot) throws {
        let payload = ReceiptPayloadDTO(
            participants: snapshot.participants.map(ParticipantDTO.init(from:)),
            items: snapshot.items.map(ReceiptItemDTO.init(from:))
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let tipModeRaw: String
        let tipPercentage: Int?
        switch snapshot.tipSelection {
        case .percentage(let pct):
            tipModeRaw = "percentage"
            tipPercentage = pct
        case .custom:
            tipModeRaw = "custom"
            tipPercentage = nil
        }

        self.init(
            receiptID: snapshot.id,
            title: snapshot.title,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            currencyCode: snapshot.currency.code,
            currencyScale: snapshot.currency.minorUnitScale,
            taxMinorUnits: snapshot.tax.amountInMinorUnits,
            tipModeRaw: tipModeRaw,
            tipPercentage: tipPercentage,
            customTipMinorUnits: snapshot.customTipMinorUnits,
            payloadData: data,
            receiptImageData: snapshot.receiptImageData,
            ocrRawText: snapshot.ocrRawText
        )
    }

    func update(from snapshot: ReceiptSnapshot) throws {
        let payload = ReceiptPayloadDTO(
            participants: snapshot.participants.map(ParticipantDTO.init(from:)),
            items: snapshot.items.map(ReceiptItemDTO.init(from:))
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let tipModeRaw: String
        let tipPercentage: Int?
        switch snapshot.tipSelection {
        case .percentage(let pct):
            tipModeRaw = "percentage"
            tipPercentage = pct
        case .custom:
            tipModeRaw = "custom"
            tipPercentage = nil
        }

        self.title = snapshot.title
        self.updatedAt = snapshot.updatedAt
        self.currencyCode = snapshot.currency.code
        self.currencyScale = snapshot.currency.minorUnitScale
        self.taxMinorUnits = snapshot.tax.amountInMinorUnits
        self.tipModeRaw = tipModeRaw
        self.tipPercentage = tipPercentage
        self.customTipMinorUnits = snapshot.customTipMinorUnits
        self.payloadData = data
        self.receiptImageData = snapshot.receiptImageData
        self.ocrRawText = snapshot.ocrRawText
    }

    func toSnapshot() throws -> ReceiptSnapshot {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ReceiptPayloadDTO.self, from: payloadData)

        let currency = Currency(code: currencyCode, minorUnitScale: currencyScale)
        let tax = Money(amountInMinorUnits: taxMinorUnits, currency: currency)

        let tipSelection: TipSelection
        if tipModeRaw == "custom" {
            tipSelection = .custom
        } else {
            tipSelection = .percentage(tipPercentage ?? 0)
        }

        let domainParticipants = try payload.participants.map { try $0.toDomainParticipant() }
        let domainItems = try payload.items.map { try $0.toDomainItem(currency: currency) }

        return ReceiptSnapshot(
            id: receiptID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            currency: currency,
            participants: domainParticipants,
            items: domainItems,
            tax: tax,
            tipSelection: tipSelection,
            customTipMinorUnits: customTipMinorUnits,
            receiptImageData: receiptImageData,
            ocrRawText: ocrRawText
        )
    }
}

// MARK: - Persistence Data Transfer Objects (DTOs)

nonisolated struct ReceiptPayloadDTO: Codable, Equatable, Sendable {
    var participants: [ParticipantDTO]
    var items: [ReceiptItemDTO]

    init(participants: [ParticipantDTO], items: [ReceiptItemDTO]) {
        self.participants = participants
        self.items = items
    }
}

nonisolated struct ParticipantDTO: Codable, Equatable, Sendable {
    let id: UUID
    let name: String

    init(from participant: Participant) {
        self.id = participant.id
        self.name = participant.name
    }

    func toDomainParticipant() throws(DomainError) -> Participant {
        try Participant(id: id, name: name)
    }
}

nonisolated enum SplitModeDTO: Codable, Equatable, Sendable {
    case wholeItem(UUID)
    case equal([UUID])
    case percentage([UUID: Int])
    case portion([UUID: Int])

    private enum CodingKeys: String, CodingKey {
        case type
        case participantID
        case participantIDs
        case shares
    }

    private enum ModeType: String, Codable {
        case wholeItem
        case equal
        case percentage
        case portion
    }

    init(from splitMode: SplitMode) {
        switch splitMode {
        case .wholeItem(let id):
            self = .wholeItem(id)
        case .equal(let ids):
            self = .equal(ids.sorted(by: { $0.uuidString < $1.uuidString }))
        case .percentage(let percentages):
            self = .percentage(percentages)
        case .portion(let portions):
            self = .portion(portions)
        }
    }

    func toDomainSplitMode() -> SplitMode {
        switch self {
        case .wholeItem(let id):
            return .wholeItem(id)
        case .equal(let ids):
            return .equal(Set(ids))
        case .percentage(let percentages):
            return .percentage(percentages)
        case .portion(let portions):
            return .portion(portions)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ModeType.self, forKey: .type)
        switch type {
        case .wholeItem:
            let id = try container.decode(UUID.self, forKey: .participantID)
            self = .wholeItem(id)
        case .equal:
            let ids = try container.decode([UUID].self, forKey: .participantIDs)
            self = .equal(ids)
        case .percentage:
            let rawShares = try container.decode([String: Int].self, forKey: .shares)
            var mapped: [UUID: Int] = [:]
            for (key, value) in rawShares {
                guard let uuid = UUID(uuidString: key) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: container.codingPath + [CodingKeys.shares],
                            debugDescription: "Invalid UUID string key: \(key)"
                        )
                    )
                }
                mapped[uuid] = value
            }
            self = .percentage(mapped)
        case .portion:
            let rawShares = try container.decode([String: Int].self, forKey: .shares)
            var mapped: [UUID: Int] = [:]
            for (key, value) in rawShares {
                guard let uuid = UUID(uuidString: key) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: container.codingPath + [CodingKeys.shares],
                            debugDescription: "Invalid UUID string key: \(key)"
                        )
                    )
                }
                mapped[uuid] = value
            }
            self = .portion(mapped)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .wholeItem(let id):
            try container.encode(ModeType.wholeItem, forKey: .type)
            try container.encode(id, forKey: .participantID)
        case .equal(let ids):
            try container.encode(ModeType.equal, forKey: .type)
            try container.encode(ids, forKey: .participantIDs)
        case .percentage(let shares):
            try container.encode(ModeType.percentage, forKey: .type)
            let stringKeyed = Dictionary(uniqueKeysWithValues: shares.map { ($0.key.uuidString, $0.value) })
            try container.encode(stringKeyed, forKey: .shares)
        case .portion(let shares):
            try container.encode(ModeType.portion, forKey: .type)
            let stringKeyed = Dictionary(uniqueKeysWithValues: shares.map { ($0.key.uuidString, $0.value) })
            try container.encode(stringKeyed, forKey: .shares)
        }
    }
}

nonisolated struct ReceiptItemDTO: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let unitPriceMinorUnits: Int64
    let quantity: Int
    let splitMode: SplitModeDTO

    init(from item: ReceiptItem) {
        self.id = item.id
        self.name = item.name
        self.unitPriceMinorUnits = item.unitPrice.amountInMinorUnits
        self.quantity = item.quantity
        self.splitMode = SplitModeDTO(from: item.splitMode)
    }

    func toDomainItem(currency: Currency) throws(DomainError) -> ReceiptItem {
        let price = Money(amountInMinorUnits: unitPriceMinorUnits, currency: currency)
        return try ReceiptItem(
            id: id,
            name: name,
            unitPrice: price,
            quantity: quantity,
            splitMode: splitMode.toDomainSplitMode()
        )
    }
}
