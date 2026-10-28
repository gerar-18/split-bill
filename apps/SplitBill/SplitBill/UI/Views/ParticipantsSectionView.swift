import SwiftUI

/// Section view responsible for currency selection, participant creation, validation feedback,
/// and participant roster management with interactive removal chips.
struct ParticipantsSectionView: View {

    // MARK: - Environment & Metrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var minChipWidth: CGFloat = 140

    // MARK: - Bindings

    @Bindable var viewModel: ReceiptEditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Currency Selector Row
            currencySelectorRow

            Divider()

            // Header & Counter
            headerRow

            // Participant Input Form
            inputRow

            // Inline Validation Banner
            if let message = viewModel.validationMessage {
                validationBanner(message: message)
            }

            // Participants Roster / Empty State
            if viewModel.participants.isEmpty {
                emptyGuidanceView
            } else {
                participantsGrid
            }
        }
        .animation(reduceMotion ? nil : .default, value: viewModel.participants)
        .animation(reduceMotion ? nil : .default, value: viewModel.validationMessage)
    }

    // MARK: - Subviews

    private var currencySelectorRow: some View {
        HStack {
            Label("Moneda", systemImage: "dollarsign.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Moneda", selection: $viewModel.currency) {
                Text("MXN ($)").tag(Currency.mxn)
                Text("USD ($)").tag(Currency.usd)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
        }
    }

    private var headerRow: some View {
        HStack {
            Label("Comensales", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if !viewModel.participants.isEmpty {
                Text("\(viewModel.participants.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Nombre de la persona", text: $viewModel.newParticipantName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(of: .text) {
                    addParticipant()
                }

            Button("Agregar", systemImage: "plus.circle.fill", action: addParticipant)
                .buttonStyle(.borderedProminent)
                .disabled(isAddDisabled)
                .frame(minHeight: 44)
        }
    }

    private func validationBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var emptyGuidanceView: some View {
        ContentUnavailableView(
            "Sin comensales",
            systemImage: "person.2.slash",
            description: Text("Agrega a las personas en la mesa para comenzar a dividir la cuenta.")
        )
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var participantsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minChipWidth), spacing: 8)], spacing: 8) {
            ForEach(viewModel.participants) { participant in
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.tint)
                        .imageScale(.medium)
                        .accessibilityHidden(true)

                    Text(participant.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Button("Eliminar \(participant.name)", systemImage: "xmark.circle.fill") {
                        removeParticipant(participant)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .padding(.leading, 10)
                .padding(.trailing, 2)
                .padding(.vertical, 2)
                .frame(minHeight: 44)
                .background(.background.secondary, in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Actions & Computed State

    private var isAddDisabled: Bool {
        viewModel.newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addParticipant() {
        guard !isAddDisabled else { return }
        viewModel.addParticipant()
    }

    private func removeParticipant(_ participant: Participant) {
        viewModel.removeParticipant(id: participant.id)
    }
}

// MARK: - Previews

#Preview("With Participants") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()
    vm.newParticipantName = "Sofía"
    vm.addParticipant()

    return ScrollView {
        ParticipantsSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Empty State") {
    let vm = ReceiptEditorViewModel()
    return ScrollView {
        ParticipantsSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Validation Banner") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "ana"
    vm.addParticipant()

    return ScrollView {
        ParticipantsSectionView(viewModel: vm)
            .padding()
    }
}
