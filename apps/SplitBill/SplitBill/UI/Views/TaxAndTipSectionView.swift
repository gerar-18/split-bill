import SwiftUI

/// Section view controlling tax input, quick preset tip buttons, custom tip entry,
/// and the live financial breakdown card with total calculation.
struct TaxAndTipSectionView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Bindings

    @Bindable var viewModel: ReceiptEditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Label("Impuestos y Propina", systemImage: "percent")
                .font(.headline)
                .foregroundStyle(.primary)

            // Tax Input Row
            taxInputRow

            Divider()

            // Tip Selector Header & Presets
            tipSection

            // Live Breakdown Card
            liveBreakdownCard
        }
    }

    // MARK: - Subviews

    private var taxInputRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Impuesto (IVA / Tax)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text("Monto exacto registrado en el recibo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("$")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("0.00", text: $viewModel.taxText)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 110)
                    .accessibilityLabel("Monto de impuesto del recibo")
            }
        }
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Propina")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(MoneyFormatter.string(from: viewModel.resolvedTip))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // Adaptive layout for presets
            ViewThatFits {
                HStack(spacing: 8) {
                    ForEach(TipSelection.presets, id: \.self) { pct in
                        tipPresetButton(percentage: pct)
                    }
                    customTipButton(isFullWidth: false)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(TipSelection.presets, id: \.self) { pct in
                            tipPresetButton(percentage: pct)
                        }
                    }
                    customTipButton(isFullWidth: true)
                }
            }

            // Custom Tip Input Field
            if viewModel.tipSelection == .custom {
                HStack {
                    Label("Monto personalizado", systemImage: "pencil.and.list.clipboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("$")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        TextField("0.00", text: $viewModel.customTipText)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 110)
                            .accessibilityLabel("Monto de propina personalizada")
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .default, value: viewModel.tipSelection)
    }

    @ViewBuilder
    private func tipPresetButton(percentage: Int) -> some View {
        let isSelected = viewModel.tipSelection == .percentage(percentage)
        let button = Button {
            selectPreset(percentage)
        } label: {
            Text("\(percentage)%")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .controlSize(.regular)
        .frame(minHeight: 44)
        .accessibilityLabel("Propina de \(percentage) por ciento")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])

        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func customTipButton(isFullWidth: Bool) -> some View {
        let isSelected = viewModel.tipSelection == .custom
        let title = isFullWidth ? "Propina Personalizada" : "Personalizada"
        let button = Button {
            selectCustom()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: isFullWidth ? .infinity : nil)
        }
        .controlSize(.regular)
        .frame(minHeight: 44)
        .accessibilityLabel("Propina personalizada")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])

        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var liveBreakdownCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Consumo / Subtotal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(MoneyFormatter.string(from: viewModel.itemsSubtotal))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Text("Impuesto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(MoneyFormatter.string(from: viewModel.resolvedTax))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Text("Propina")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(MoneyFormatter.string(from: viewModel.resolvedTip))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Gran Total")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(MoneyFormatter.string(from: viewModel.grandTotal))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func selectPreset(_ percentage: Int) {
        viewModel.tipSelection = .percentage(percentage)
    }

    private func selectCustom() {
        viewModel.tipSelection = .custom
    }
}

// MARK: - Previews

#Preview("Tax and Tip - Default Preset") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()

    if let p1 = vm.participants.first, let p2 = vm.participants.last {
        if let item1 = try? ReceiptItem(
            name: "Guacamole y Totopos",
            unitPrice: Money(amountInMinorUnits: 14000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([p1.id, p2.id])
        ),
        let item2 = try? ReceiptItem(
            name: "Tacos al Pastor",
            unitPrice: Money(amountInMinorUnits: 18000, currency: .mxn),
            quantity: 2,
            splitMode: .wholeItem(p1.id)
        ) {
            vm.items = [item1, item2]
        }
    }
    vm.taxText = "80.00"
    vm.tipSelection = .percentage(15)

    return ScrollView {
        TaxAndTipSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Tax and Tip - Custom Amount") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Sofía"
    vm.addParticipant()

    if let p = vm.participants.first {
        if let item = try? ReceiptItem(
            name: "Ensalada César",
            unitPrice: Money(amountInMinorUnits: 19500, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(p.id)
        ) {
            vm.items = [item]
        }
    }
    vm.taxText = "31.20"
    vm.tipSelection = .custom
    vm.customTipText = "50.00"

    return ScrollView {
        TaxAndTipSectionView(viewModel: vm)
            .padding()
    }
}
