import SwiftUI

/// Modal sheet presenting application version details, local-first privacy commitments,
/// and verified links to the Privacy Policy and Support pages (Apple Guidelines 1.5 & 5.1.1(i)).
struct AboutPrivacySheet: View {

    // MARK: - Environment & State

    @Environment(\.dismiss) private var dismiss
    @State private var hasConsent: Bool = false
    let metadata: AppMetadata
    private let consentStore: any AIConsentStoring

    init(
        metadata: AppMetadata = .current(),
        consentStore: any AIConsentStoring = UserDefaultsAIConsentStore()
    ) {
        self.metadata = metadata
        self.consentStore = consentStore
        _hasConsent = State(initialValue: consentStore.hasGrantedConsent)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    privacyCardView
                    aiPrivacyCardView
                    featuresCardView
                    legalLinksCardView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Acerca de")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                    .accessibilityLabel("Cerrar ventana de información")
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.teal.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text(metadata.appName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(metadata.formattedVersion)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var privacyCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Privacidad Local-First", systemImage: "lock.shield.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                privacyBullet(
                    icon: "iphone.gen3",
                    title: "Procesamiento 100% en tu iPhone",
                    description: "Las fotos de tus recibos, el OCR con Apple Vision y el historial de cuentas permanecen en tu dispositivo."
                )

                Divider()

                privacyBullet(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Sin registro ni cuentas",
                    description: "No necesitas ingresar correos, contraseñas ni registrarte para utilizar la aplicación completa."
                )

                Divider()

                privacyBullet(
                    icon: "hand.raised.slash.fill",
                    title: "Cero rastreadores publicitarios",
                    description: "SplitBill no incluye anuncios, SDKs de rastreo publicitario ni vende tus hábitos de consumo."
                )
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var aiPrivacyCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Extracción Inteligente con IA", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.purple)

            Text("SplitBill incluye un asistente opcional que interpreta tickets complejos utilizando IA segura. Requiere tu consentimiento explícito antes de enviar cualquier texto (Apple Guideline 5.1.2(i)).")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estado del consentimiento:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if hasConsent {
                        Text("Consentimiento activo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("No otorgado")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if hasConsent {
                    Button(role: .destructive) {
                        consentStore.revokeConsent()
                        hasConsent = consentStore.hasGrantedConsent
                    } label: {
                        Text("Revocar")
                            .font(.caption.weight(.semibold))
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Revocar consentimiento de procesamiento con IA")
                }
            }
            .padding(12)
            .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func privacyBullet(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var featuresCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Precisión Financiera", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Todas las divisiones, impuestos y propinas se calculan con centavos enteros exactos mediante el Método de Hamilton, garantizando que el total pagado cuadre al centavo sin pérdidas por redondeo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var legalLinksCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enlaces y Asistencia", systemImage: "link")
                .font(.headline)
                .foregroundStyle(.primary)

            Link(destination: metadata.privacyPolicyURL) {
                HStack {
                    Label("Política de Privacidad", systemImage: "hand.raised.fill")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Abrir Política de Privacidad en el navegador")

            Divider()

            Link(destination: metadata.supportURL) {
                HStack {
                    Label("Soporte y Contacto", systemImage: "questionmark.circle.fill")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Abrir página de soporte y contacto en el navegador")
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Previews

#Preview {
    AboutPrivacySheet()
}
