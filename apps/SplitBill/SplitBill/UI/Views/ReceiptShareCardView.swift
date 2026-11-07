import SwiftUI

/// A beautifully styled receipt infographic view designed for visual card rendering and sharing.
struct ReceiptShareCardView: View {

    // MARK: - Properties

    let data: ReceiptShareCardData
    let theme: ReceiptCardTheme
    let showsItemizedDetails: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            totalHighlightSection
            participantsSection
            footerSection
        }
        .frame(width: 380)
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(theme.dividerColor, lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            // App Branding Badge
            HStack(spacing: 6) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.caption.weight(.bold))
                Text("SplitBill")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.teal],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )

            // Receipt Title
            Text(data.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.primaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            // Date
            Text(data.dateText)
                .font(.caption)
                .foregroundStyle(theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var totalHighlightSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("TOTAL GENERAL")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryTextColor)
                    .tracking(1)

                Text(MoneyFormatter.string(from: data.grandTotal))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.primaryTextColor)
            }

            // Subtotal / Tax / Tip breakdown pills
            HStack(spacing: 8) {
                metricPill(
                    label: "Consumo",
                    amount: MoneyFormatter.string(from: data.itemsSubtotal, includeCurrencyCode: false)
                )

                if data.hasTax {
                    metricPill(
                        label: "IVA",
                        amount: MoneyFormatter.string(from: data.tax, includeCurrencyCode: false)
                    )
                }

                if data.hasTip {
                    metricPill(
                        label: "Propina",
                        amount: MoneyFormatter.string(from: data.tip, includeCurrencyCode: false)
                    )
                }
            }

            // Hamilton Master Reconciliation Badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Reconciliado al centavo exacto (Hamilton)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func metricPill(label: String, amount: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondaryTextColor)
            Text(amount)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(theme.primaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var participantsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("DESGLOSE POR PERSONA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryTextColor)
                    .tracking(0.8)
                Spacer()
                Text("\(data.participantRows.count) comensales")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryTextColor)
            }
            .padding(.horizontal, 4)

            ForEach(data.participantRows) { row in
                participantCard(row: row)
            }
        }
        .padding(16)
    }

    private func participantCard(row: ReceiptShareCardData.ParticipantShareRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Participant Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 30, height: 30)

                    Image(systemName: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                Text(row.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryTextColor)
                    .lineLimit(1)

                Spacer()

                Text(MoneyFormatter.string(from: row.total))
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(theme.primaryTextColor)
            }

            // Participant Sub-metrics
            HStack(spacing: 12) {
                Text("Consumo: \(MoneyFormatter.string(from: row.itemsSubtotal, includeCurrencyCode: false))")
                if row.tax.amountInMinorUnits > 0 {
                    Text("IVA: \(MoneyFormatter.string(from: row.tax, includeCurrencyCode: false))")
                }
                if row.tip.amountInMinorUnits > 0 {
                    Text("Propina: \(MoneyFormatter.string(from: row.tip, includeCurrencyCode: false))")
                }
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(theme.secondaryTextColor)

            // Optional Itemized assigned dishes
            if showsItemizedDetails && !row.assignedItems.isEmpty {
                Divider()
                    .overlay(theme.dividerColor)

                VStack(spacing: 4) {
                    ForEach(row.assignedItems) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .lineLimit(1)

                            Spacer()

                            Text(MoneyFormatter.string(from: item.share, includeCurrencyCode: false))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.dividerColor, lineWidth: 0.5)
        )
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            // Perforated Line
            HStack(spacing: 6) {
                ForEach(0..<20) { _ in
                    Circle()
                        .fill(theme.dividerColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Text("Calculado con SplitBill • 100% Local-First")
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - ImageRenderer Utility

/// Utility providing MainActor-isolated rendering of `ReceiptShareCardView`
/// into high-resolution `UIImage` and PNG `Data`.
@MainActor
enum ReceiptCardRenderer {

    /// Renders a `ReceiptShareCardData` into a high-resolution `UIImage` (scale 3.0).
    static func renderImage(
        data: ReceiptShareCardData,
        theme: ReceiptCardTheme = .classicLight,
        showsItemizedDetails: Bool = true
    ) -> UIImage? {
        let cardView = ReceiptShareCardView(
            data: data,
            theme: theme,
            showsItemizedDetails: showsItemizedDetails
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // High resolution Retina scale (1140 px width)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Renders a `ReceiptShareCardData` into PNG encoded `Data`.
    static func renderPNGData(
        data: ReceiptShareCardData,
        theme: ReceiptCardTheme = .classicLight,
        showsItemizedDetails: Bool = true
    ) -> Data? {
        guard let uiImage = renderImage(
            data: data,
            theme: theme,
            showsItemizedDetails: showsItemizedDetails
        ) else {
            return nil
        }
        return uiImage.pngData()
    }
}

// MARK: - Previews

#Preview("Classic Light") {
    let p1 = try! Participant(name: "Ana García")
    let p2 = try! Participant(name: "Carlos Rivera")
    let previewData = ReceiptShareCardData(
        title: "Cena Taquería El Pastor",
        dateText: "6 nov 2026",
        currency: .mxn,
        itemsSubtotal: Money(amountInMinorUnits: 43000, currency: .mxn),
        tax: Money(amountInMinorUnits: 6880, currency: .mxn),
        tip: Money(amountInMinorUnits: 4300, currency: .mxn),
        grandTotal: Money(amountInMinorUnits: 54180, currency: .mxn),
        participantRows: [
            ReceiptShareCardData.ParticipantShareRow(
                id: p1.id,
                name: p1.name,
                total: Money(amountInMinorUnits: 27090, currency: .mxn),
                itemsSubtotal: Money(amountInMinorUnits: 21500, currency: .mxn),
                tax: Money(amountInMinorUnits: 3440, currency: .mxn),
                tip: Money(amountInMinorUnits: 2150, currency: .mxn),
                assignedItems: [
                    ReceiptShareCardData.AssignedItemShare(
                        id: UUID(),
                        name: "Orden Tacos al Pastor",
                        share: Money(amountInMinorUnits: 17000, currency: .mxn),
                        quantity: 2
                    ),
                    ReceiptShareCardData.AssignedItemShare(
                        id: UUID(),
                        name: "Agua de Horchata",
                        share: Money(amountInMinorUnits: 4500, currency: .mxn),
                        quantity: 1
                    )
                ]
            ),
            ReceiptShareCardData.ParticipantShareRow(
                id: p2.id,
                name: p2.name,
                total: Money(amountInMinorUnits: 27090, currency: .mxn),
                itemsSubtotal: Money(amountInMinorUnits: 21500, currency: .mxn),
                tax: Money(amountInMinorUnits: 3440, currency: .mxn),
                tip: Money(amountInMinorUnits: 2150, currency: .mxn),
                assignedItems: [
                    ReceiptShareCardData.AssignedItemShare(
                        id: UUID(),
                        name: "Gringa Especial",
                        share: Money(amountInMinorUnits: 17000, currency: .mxn),
                        quantity: 1
                    ),
                    ReceiptShareCardData.AssignedItemShare(
                        id: UUID(),
                        name: "Cerveza Corona",
                        share: Money(amountInMinorUnits: 4500, currency: .mxn),
                        quantity: 1
                    )
                ]
            )
        ]
    )

    return ScrollView {
        ReceiptShareCardView(
            data: previewData,
            theme: .classicLight,
            showsItemizedDetails: true
        )
        .padding()
    }
}
