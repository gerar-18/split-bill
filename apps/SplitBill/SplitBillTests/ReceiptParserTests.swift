import Testing
import Foundation
@testable import SplitBill

@Suite("Receipt Parser Tests")
struct ReceiptParserTests {

    let parser = DeterministicReceiptParser()

    // MARK: - Sample Preset 1: Taquería El Pastor

    @Test("DeterministicReceiptParser faithfully parses Taquería El Pastor sample ticket")
    func parseTaqueriaElPastor() {
        let ticket = """
        TAQUERÍA EL PASTOR
        Av. Insurgentes Sur 1234, CDMX
        Ticket #00428  •  2026-11-05 14:32
        --------------------------------
        DESCRIPCIÓN IMPORTE
        2x Tacos al Pastor $170.00
           (2 @ $85.00)
        Gringa de Pastor $95.00
        Guacamole Especial $75.00
        2x Agua de Horchata 1L $90.00
           (2 @ $45.00)
        --------------------------------
        SUBTOTAL $430.00
        IVA (16%) $68.80
        --------------------------------
        TOTAL $498.80
        PROPINA SUGERIDA $43.00 (10%)
        --------------------------------
        ¡GRACIAS POR SU PREFERENCIA!
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.merchantName == "TAQUERÍA EL PASTOR")
        #expect(result.items.count == 4)

        // Item 1: 2x Tacos al Pastor
        #expect(result.items[0].name == "Tacos al Pastor")
        #expect(result.items[0].quantity == 2)
        #expect(result.items[0].unitPrice == Money(amountInMinorUnits: 8500, currency: .mxn))
        #expect(result.items[0].lineTotal == Money(amountInMinorUnits: 17000, currency: .mxn))

        // Item 2: Gringa de Pastor
        #expect(result.items[1].name == "Gringa de Pastor")
        #expect(result.items[1].quantity == 1)
        #expect(result.items[1].unitPrice == Money(amountInMinorUnits: 9500, currency: .mxn))
        #expect(result.items[1].lineTotal == Money(amountInMinorUnits: 9500, currency: .mxn))

        // Item 3: Guacamole Especial
        #expect(result.items[2].name == "Guacamole Especial")
        #expect(result.items[2].quantity == 1)
        #expect(result.items[2].unitPrice == Money(amountInMinorUnits: 7500, currency: .mxn))
        #expect(result.items[2].lineTotal == Money(amountInMinorUnits: 7500, currency: .mxn))

        // Item 4: 2x Agua de Horchata 1L
        #expect(result.items[3].name == "Agua de Horchata 1L")
        #expect(result.items[3].quantity == 2)
        #expect(result.items[3].unitPrice == Money(amountInMinorUnits: 4500, currency: .mxn))
        #expect(result.items[3].lineTotal == Money(amountInMinorUnits: 9000, currency: .mxn))

        // Summary Line Verifications
        #expect(result.detectedSubtotal == Money(amountInMinorUnits: 43000, currency: .mxn))
        #expect(result.detectedTax == Money(amountInMinorUnits: 6880, currency: .mxn))
        #expect(result.detectedTotal == Money(amountInMinorUnits: 49880, currency: .mxn))
        #expect(result.detectedSuggestedTip == Money(amountInMinorUnits: 4300, currency: .mxn))
        #expect(result.detectedTipPercentage == 10)

        // Mathematical Reconciliation
        #expect(result.reconciliation.status == .verified)
        #expect(result.reconciliation.subtotalMatches == true)
        #expect(result.reconciliation.totalMatches == true)
        #expect(result.reconciliation.computedItemsSubtotal == Money(amountInMinorUnits: 43000, currency: .mxn))
    }

    // MARK: - Sample Preset 2: Pizzería Napoli

    @Test("DeterministicReceiptParser faithfully parses Pizzería Napoli sample ticket")
    func parsePizzeriaNapoli() {
        let ticket = """
        PIZZERÍA NAPOLI
        Calle Orizaba 45, Roma Norte, CDMX
        Ticket #01892  •  2026-11-05 20:15
        --------------------------------
        DESCRIPCIÓN IMPORTE
        Pizza Margherita $220.00
        Pizza Quattro Formaggi $280.00
        Ensalada Caprese $160.00
        2x Copa Vino Tinto $260.00
           (2 @ $130.00)
        --------------------------------
        SUBTOTAL $920.00
        IVA (16%) $147.20
        --------------------------------
        TOTAL $1,067.20
        PROPINA SUGERIDA $138.00 (15%)
        --------------------------------
        ¡GRACIAS POR SU PREFERENCIA!
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.merchantName == "PIZZERÍA NAPOLI")
        #expect(result.items.count == 4)

        #expect(result.items[0].name == "Pizza Margherita")
        #expect(result.items[0].quantity == 1)
        #expect(result.items[0].lineTotal == Money(amountInMinorUnits: 22000, currency: .mxn))

        #expect(result.items[1].name == "Pizza Quattro Formaggi")
        #expect(result.items[1].quantity == 1)
        #expect(result.items[1].lineTotal == Money(amountInMinorUnits: 28000, currency: .mxn))

        #expect(result.items[2].name == "Ensalada Caprese")
        #expect(result.items[2].quantity == 1)
        #expect(result.items[2].lineTotal == Money(amountInMinorUnits: 16000, currency: .mxn))

        #expect(result.items[3].name == "Copa Vino Tinto")
        #expect(result.items[3].quantity == 2)
        #expect(result.items[3].unitPrice == Money(amountInMinorUnits: 13000, currency: .mxn))
        #expect(result.items[3].lineTotal == Money(amountInMinorUnits: 26000, currency: .mxn))

        #expect(result.detectedSubtotal == Money(amountInMinorUnits: 92000, currency: .mxn))
        #expect(result.detectedTax == Money(amountInMinorUnits: 14720, currency: .mxn))
        #expect(result.detectedTotal == Money(amountInMinorUnits: 106720, currency: .mxn))
        #expect(result.detectedSuggestedTip == Money(amountInMinorUnits: 13800, currency: .mxn))
        #expect(result.detectedTipPercentage == 15)

        #expect(result.reconciliation.status == .verified)
        #expect(result.reconciliation.subtotalMatches == true)
        #expect(result.reconciliation.totalMatches == true)
    }

    // MARK: - Sample Preset 3: Café Roma / Café Central

    @Test("DeterministicReceiptParser faithfully parses Café Central / Roma sample ticket")
    func parseCafeCentral() {
        let ticket = """
        CAFÉ ROMA
        Paseo de la Reforma 222, CDMX
        Ticket #00104  •  2026-11-05 09:45
        --------------------------------
        DESCRIPCIÓN IMPORTE
        2x Café Americano $100.00
           (2 @ $50.00)
        Croissant Mantequilla $55.00
        Huevos Benedictinos $165.00
        Jugo Verde Natural $60.00
        --------------------------------
        SUBTOTAL $380.00
        IVA (16%) $60.80
        --------------------------------
        TOTAL $440.80
        PROPINA SUGERIDA $38.00 (10%)
        --------------------------------
        ¡GRACIAS POR SU PREFERENCIA!
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.merchantName == "CAFÉ ROMA")
        #expect(result.items.count == 4)

        #expect(result.items[0].name == "Café Americano")
        #expect(result.items[0].quantity == 2)
        #expect(result.items[0].unitPrice == Money(amountInMinorUnits: 5000, currency: .mxn))
        #expect(result.items[0].lineTotal == Money(amountInMinorUnits: 10000, currency: .mxn))

        #expect(result.items[1].name == "Croissant Mantequilla")
        #expect(result.items[1].quantity == 1)
        #expect(result.items[1].lineTotal == Money(amountInMinorUnits: 5500, currency: .mxn))

        #expect(result.items[2].name == "Huevos Benedictinos")
        #expect(result.items[2].quantity == 1)
        #expect(result.items[2].lineTotal == Money(amountInMinorUnits: 16500, currency: .mxn))

        #expect(result.items[3].name == "Jugo Verde Natural")
        #expect(result.items[3].quantity == 1)
        #expect(result.items[3].lineTotal == Money(amountInMinorUnits: 6000, currency: .mxn))

        #expect(result.detectedSubtotal == Money(amountInMinorUnits: 38000, currency: .mxn))
        #expect(result.detectedTax == Money(amountInMinorUnits: 6080, currency: .mxn))
        #expect(result.detectedTotal == Money(amountInMinorUnits: 44080, currency: .mxn))
        #expect(result.detectedSuggestedTip == Money(amountInMinorUnits: 3800, currency: .mxn))
        #expect(result.detectedTipPercentage == 10)

        #expect(result.reconciliation.status == .verified)
        #expect(result.reconciliation.subtotalMatches == true)
        #expect(result.reconciliation.totalMatches == true)
    }

    // MARK: - Edge Cases

    @Test("Discrepancy detected when computed sum does not equal grand total")
    func edgeCaseDiscrepancy() {
        let ticket = """
        RESTAURANTE EL ERROR
        Hamburguesa Clásica $100.00
        SUBTOTAL $100.00
        IVA $16.00
        TOTAL $130.00
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.items.count == 1)
        #expect(result.reconciliation.subtotalMatches == true)
        #expect(result.reconciliation.totalMatches == false)
        // Expected: 10000 + 1600 = 11600. Actual: 13000. Diff = +1400 cents ($14.00)
        #expect(result.reconciliation.status == .discrepancy(differenceInMinorUnits: 1400, currency: .mxn))
    }

    @Test("Non-divisible promo preserves exact line total without lost cents")
    func edgeCaseNonDivisiblePromo() {
        let ticket = """
        TAQUERÍA MIXTA
        3x Combo Especial $100.00
        TOTAL $100.00
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.items.count == 1)
        let item = result.items[0]
        #expect(item.quantity == 1)
        #expect(item.unitPrice == Money(amountInMinorUnits: 10000, currency: .mxn))
        #expect(item.lineTotal == Money(amountInMinorUnits: 10000, currency: .mxn))
        #expect(result.reconciliation.status == .verified)
    }

    @Test("Lookbehind detail line updates previously added dish item")
    func edgeCaseLookbehindDetailLine() {
        let ticket = """
        LA PIZZERIA
        Copa de Vino $260.00
        (2 @ $130.00)
        TOTAL $260.00
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.items.count == 1)
        let item = result.items[0]
        #expect(item.name == "Copa de Vino")
        #expect(item.quantity == 2)
        #expect(item.unitPrice == Money(amountInMinorUnits: 13000, currency: .mxn))
        #expect(item.lineTotal == Money(amountInMinorUnits: 26000, currency: .mxn))
        #expect(result.reconciliation.status == .verified)
    }

    @Test("Partial status returned when ticket lacks grand total and subtotal")
    func edgeCasePartial() {
        let ticket = """
        CAFETERIA
        Café Americano $45.00
        Pan Dulce $30.00
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.items.count == 2)
        #expect(result.reconciliation.status == .partial)
        #expect(result.reconciliation.subtotalMatches == nil)
        #expect(result.reconciliation.totalMatches == nil)
    }

    @Test("Empty status returned for empty or noise-only receipts")
    func edgeCaseEmpty() {
        let emptyTicket = """
        -----------------------------
        =============================

        """

        let result = parser.parse(rawText: emptyTicket, currency: .mxn)

        #expect(result.items.isEmpty)
        #expect(result.reconciliation.status == .empty)
    }

    @Test("Noise lines, table headers, payment methods, and footers are cleanly ignored")
    func edgeCaseNoiseIgnored() {
        let ticket = """
        TACOS EXPRESS
        Av. Siempre Viva 742, CDMX
        Ticket #99881  •  2026-11-05 18:00
        ================================
        CANT DESCRIPCIÓN IMPORTE
        1 Torta de Pastor $70.00
        SUBTOTAL $70.00
        TOTAL $70.00
        ================================
        EFECTIVO $100.00
        CAMBIO $30.00
        TARJETA DE CREDITO
        ¡GRACIAS POR SU VISITA!
        VUELVA PRONTO
        """

        let result = parser.parse(rawText: ticket, currency: .mxn)

        #expect(result.items.count == 1)
        #expect(result.items[0].name == "Torta de Pastor")
        #expect(result.items[0].quantity == 1)
        #expect(result.items[0].lineTotal == Money(amountInMinorUnits: 7000, currency: .mxn))
        #expect(result.reconciliation.status == .verified)
        #expect(result.reconciliation.totalMatches == true)
        #expect(result.unclassifiedLines.isEmpty)
    }

    // MARK: - MoneyParser Direct Unit Tests

    @Test("MoneyParser parses valid prices into exact minor units")
    func moneyParserValid() {
        #expect(MoneyParser.parseMajorUnits(from: "$85.00") == Money(amountInMinorUnits: 8500, currency: .mxn))
        #expect(MoneyParser.parseMajorUnits(from: "1,067.20") == Money(amountInMinorUnits: 106720, currency: .mxn))
        #expect(MoneyParser.parseMajorUnits(from: "  $ 45.5 MXN  ") == Money(amountInMinorUnits: 4550, currency: .mxn))
        #expect(MoneyParser.parseMajorUnits(from: "125,50") == Money(amountInMinorUnits: 12550, currency: .mxn))
        #expect(MoneyParser.parseMajorUnits(from: "120") == Money(amountInMinorUnits: 12000, currency: .mxn))
    }

    @Test("MoneyParser returns nil for invalid input or negative amounts")
    func moneyParserInvalid() {
        #expect(MoneyParser.parseMajorUnits(from: "-$10.00") == nil)
        #expect(MoneyParser.parseMajorUnits(from: "abc") == nil)
        #expect(MoneyParser.parseMajorUnits(from: "") == nil)
        #expect(MoneyParser.parseMajorUnits(from: "$") == nil)
    }
}
