# Learning Log

## M0 — Engineering Foundation & Agentic Infrastructure

Status: Completed

### Concepts learned
- [x] **Git en Monorepos y proyectos Xcode**: Por qué ocurre el problema de *Embedded Git Repository* cuando Xcode inicializa su propio `.git` en subcarpetas (`apps/SplitBill/.git`), cómo resolverlo y la importancia de ignorar `xcuserdata/` para evitar colisiones de estado personal en equipos.
- [x] **Estructura moderna de proyectos Xcode**: Comprensión de `PBXFileSystemSynchronizedRootGroup` (novedad en Xcode 16+ para sincronizar archivos en disco automáticamente) y por qué archivos con nombres duplicados (como `.gitkeep`) provocan errores de recursos duplicados (`CpResource`).
- [x] **Swift Testing vs XCTest**: Adopción del estándar moderno de pruebas en Swift 6 (`import Testing`, macros `@Test`, aserciones contextuales con `#expect`) en lugar del legado basado en clases de Objective-C (`XCTestCase`).
- [x] **Configuración de Schemes Compartidos (`xcshareddata`)**: Creación de esquemas reproducibles en `SplitBill.xcscheme` para permitir que herramientas CLI (`xcodebuild`) y agentes ejecuten suites de pruebas sin depender de la UI de Xcode.
- [x] **Guardrails de Arquitectura en CI/CLI**: Automatización con [`scripts/verify.sh`](scripts/verify.sh) para verificar de forma estática que la capa de Dominio nunca importe SwiftUI ([ADR-002](docs/decisions/ADR-002-domain-separation.md)) antes de compilar y correr pruebas.
- [x] **Context Engineering — Reglas vs. Skills vs. Subagentes**:
  - **Reglas (`AGENTS.md`)**: Invariantes globales siempre presentes en el contexto.
  - **Skills (`.agents/skills/`)**: Runbooks procedimentales cargados bajo demanda (*Progressive Disclosure*). Aprendimos por qué deben contener comandos, plantillas de código y checklists en lugar de resúmenes abstractos de un párrafo.
  - **Subagentes (`.agents/agents/`)**: Especialistas con contexto aislado (`planner`, `ios-engineer`, `qa-engineer`, `code-reviewer`) conectados mediante contratos explícitos de entrada/salida (*Handoff Contracts*) y matrices de activación de skills.
- [x] **Ecosistema `find-skills` (`npx skills`)**: Búsqueda, evaluación por reputación/instalaciones e instalación con `--copy` de skills de la comunidad (`swiftui-pro`, `swift-testing-pro`, `swift-concurrency-pro`, `mobile-ios-design`, `security-review`), más limpieza de carpetas redundantes de plugins para mantener un descubrimiento limpio en Antigravity.

### Agent contribution
- Diagnóstico del repositorio embebido de Git y corrección de `.gitignore`.
- Configuración del target de pruebas `SplitBillTests` en `project.pbxproj` vinculado con el framework moderno *Swift Testing*.
- Creación del esquema compartido `SplitBill.xcscheme` y del script reproducible [`scripts/verify.sh`](scripts/verify.sh).
- Evolución de los 4 subagentes en [`.agents/agents/`](.agents/agents) y las 7 skills del proyecto en [`.agents/skills/`](.agents/skills) con ejemplos Swift 6 y criterios claros de activación.
- Instalación y curación de 5 skills especializadas de la comunidad (`swiftui-pro`, `swift-testing-pro`, `swift-concurrency-pro`, `mobile-ios-design`, `security-review`).
- Creación de la guía y matriz de decisión en [`AGENTS.md`](AGENTS.md), [`docs/ai/agents-and-skills.md`](docs/ai/agents-and-skills.md) y [`docs/ai/agent-workflow.md`](docs/ai/agent-workflow.md).

### Human understanding
- M0 establece las bases para trabajar de manera iterativa y profesional: cada cambio que haga el desarrollador o el agente puede validarse en segundos con `./scripts/verify.sh`.
- Existe un mapa claro de qué subagente y qué skill usar en cada etapa del desarrollo (Planificación → Implementación → QA → Code Review).

### Open questions
- En M1 definiremos e implementaremos el tipo `Money` (modelado con enteros en centavos `Int64` + `Currency`) y el motor de división determinista (`SplitEngine`).

---

## M1 — Split Engine

Status: Completed (4/4 tasks completed)

### Task 1: `DomainError`, `Currency` y `Money`
- **Concepts learned**:
  - [x] **Unidades mínimas enteras (`Int64`) vs. Punto flotante (`Double`/`Float`)**: Almacenar montos en centavos enteros (`amountInMinorUnits: Int64`) evita errores binarios de IEEE 754 (`0.1 + 0.2 != 0.3`) y soporta cuentas grandes (`5_000_000_000` centavos) sin pérdida de precisión.
  - [x] **Typed Throws en Swift 6 (`throws(DomainError)`)**: Permite declarar en la firma de cada método exactamente qué tipo de error puede lanzar (`DomainError`), habilitando validación exhaustiva en compilación y pruebas expresivas como `#expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd))`.
  - [x] **`nonisolated` en Tipos de Valor bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**: Dado que Xcode 27 aísla tipos por defecto en `@MainActor`, marcar los modelos puros del dominio (`DomainError`, `Currency`, `Money`) como `nonisolated` permite usarlos libremente desde cualquier actor, hilo de fondo o pruebas parametrizadas `@Test(arguments:)` sin saltos de concurrencia innecesarios.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Domain/DomainError.swift`](apps/SplitBill/SplitBill/Domain/DomainError.swift)
  - [`apps/SplitBill/SplitBill/Domain/Money.swift`](apps/SplitBill/SplitBill/Domain/Money.swift)
  - [`apps/SplitBill/SplitBillTests/MoneyTests.swift`](apps/SplitBill/SplitBillTests/MoneyTests.swift)

### Task 2: `Participant`, `SplitMode` y `ReceiptItem`
- **Concepts learned**:
  - [x] **Hacer que los estados inválidos sean irrepresentables (*Make Illegal States Unrepresentable*)**: Validar nombres vacíos (`trimmingCharacters(in: .whitespacesAndNewlines)`), precios negativos y cantidades `< 1` directamente en el inicializador (`init(...) throws(DomainError)`) garantiza que cualquier instancia de `Participant` o `ReceiptItem` en memoria sea válida por construcción.
  - [x] **Tipos Suma (`enum` con valores asociados) para `SplitMode`**: Representar los 4 modos de división (`.wholeItem`, `.equal`, `.percentage`, `.portion`) en un `enum` obliga al compilador a verificar con `switch` exhaustivo que siempre manejemos los 4 casos sin olvidar ninguno.
  - [x] **Identidad con `Identifiable` y `Participant.ID`**: Usar `Participant.ID` (`UUID`) en lugar de nombres (`String`) en `SplitMode` y `ReceiptItem` permite que dos personas o dos platillos se llamen igual en la misma mesa sin colisionar.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Domain/Participant.swift`](apps/SplitBill/SplitBill/Domain/Participant.swift)
  - [`apps/SplitBill/SplitBill/Domain/SplitMode.swift`](apps/SplitBill/SplitBill/Domain/SplitMode.swift)
  - [`apps/SplitBill/SplitBill/Domain/ReceiptItem.swift`](apps/SplitBill/SplitBill/Domain/ReceiptItem.swift)
  - [`apps/SplitBill/SplitBillTests/DomainEntityTests.swift`](apps/SplitBill/SplitBillTests/DomainEntityTests.swift)

### Task 3: Algoritmo Largest Remainder y División por Artículo (`SplitEngine` Parte 1)
- **Concepts learned**:
  - [x] **Método de Hamilton (*Largest Remainder Method*)**: Separa el cociente entero base $q_i = \lfloor (A \times w_i) / W \rfloor$ del numerador de residuo exacto $r_i = (A \times w_i) \bmod W$, repartiendo los centavos sobrantes $R = A - \sum q_i$ primero a quienes tienen mayor residuo $r_i$ y desempatando por orden de participante (`orderIndex`).
  - [x] **Aritmética de 128 bits (`multipliedFullWidth` / `dividingFullWidth`)**: Evita desbordamientos de `Int64` al multiplicar montos grandes por pesos grandes antes de dividir entre el peso total.
  - [x] **Unificación de los 4 modos de `SplitMode` en pesos enteros**: `.wholeItem` (peso `1`), `.equal` (peso `1` para cada asignado), `.percentage` (peso = porcentaje) y `.portion` (peso = porciones) se reducen al mismo algoritmo matemático verificado.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Domain/SplitEngine.swift`](apps/SplitBill/SplitBill/Domain/SplitEngine.swift)
  - [`apps/SplitBill/SplitBillTests/ItemSplitTests.swift`](apps/SplitBill/SplitBillTests/ItemSplitTests.swift)

### Task 4: `Receipt`, Impuestos/Propina Proporcionales y Reconciliación Final (`SplitEngine` Parte 2)
- **Concepts learned**:
  - [x] **Reparto Proporcional de Impuesto y Propina**: Distribuir `tax` y `tip` usando el subtotal consumido por cada persona como ponderación garantiza justicia distributiva (quien no consumió alimentos no paga IVA ni propina).
  - [x] **Invariante Maestro del Recibo**: Verificación estricta de que $\sum \text{persona.total} == \text{receipt.total}$ para cualquier combinación de artículos, porcentajes, porciones, impuestos y propinas.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Domain/Receipt.swift`](apps/SplitBill/SplitBill/Domain/Receipt.swift)
  - [`apps/SplitBill/SplitBill/Domain/SplitEngine.swift`](apps/SplitBill/SplitBill/Domain/SplitEngine.swift) (completado con `calculateSplit`)
  - [`apps/SplitBill/SplitBillTests/ReceiptSplitEngineTests.swift`](apps/SplitBill/SplitBillTests/ReceiptSplitEngineTests.swift)
  - [`docs/domain/money-and-splitting.md`](docs/domain/money-and-splitting.md) (especificación actualizada)

## Milestone M2: iOS UI (Complete Manual Split Flow)

Status: Completed (4/4 tasks completed)

### Task 1: Parser Monetario Determinista y `@Observable` ViewModel + Pruebas Unitarias
- **Concepts learned**:
  - [x] **Parseo Monetario Entero sin `Double`**: `MoneyFormatter.parseMinorUnits` procesa cadenas decimales de usuario (ej. `"125.50"`, `"$45.5"`, `"1,234.50"`) y las escala a centavos enteros (`Int64`) directamente mediante potencias de 10 y validación estricta de dígitos ASCII. Elimina cualquier riesgo de errores de precisión binaria IEEE 754.
  - [x] **Aritmética Entera *Half-Up* para Propinas**: `TipSelection.resolveMoney` calcula propinas de porcentaje mediante `(subtotal * pct + 50) / 100`, logrando redondeo exacto al entero más cercano con pura matemática entera.
  - [x] **Observation Framework (`@Observable`) y Aislamiento `@MainActor`**: `ReceiptEditorViewModel` se anota con `@Observable` y `@MainActor`, orquestando los borradores de UI y recalculando en vivo el recibo y el desglose delegando a las entidades puras de `Domain/` (`ADR-002`).
  - [x] **Borrado Seguro y Cascadas en la UI**: Al remover participantes, el ViewModel limpia de manera defensiva las asignaciones en los ítems existentes (reasignando `.wholeItem` al primer participante disponible o convirtiendo `.percentage` a 100% / `.equal`), evitando que el estado quede corrupto.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Formatting/MoneyFormatter.swift`](apps/SplitBill/SplitBill/UI/Formatting/MoneyFormatter.swift)
  - [`apps/SplitBill/SplitBill/UI/State/TipSelection.swift`](apps/SplitBill/SplitBill/UI/State/TipSelection.swift)
  - [`apps/SplitBill/SplitBill/UI/State/SplitModeKind.swift`](apps/SplitBill/SplitBill/UI/State/SplitModeKind.swift)
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptItemDraft.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptItemDraft.swift)
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`apps/SplitBill/SplitBillTests/MoneyFormatterTests.swift`](apps/SplitBill/SplitBillTests/MoneyFormatterTests.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptEditorViewModelTests.swift`](apps/SplitBill/SplitBillTests/ReceiptEditorViewModelTests.swift)

### Task 2: Secciones de Participantes, Selector de Moneda y Controles de Impuestos/Propina
- **Concepts learned**:
  - [x] **Proyección con `@Bindable` en Vistas Hijas**: Recibir `@Bindable var viewModel: ReceiptEditorViewModel` permite derivar bindings bidireccionales (`$viewModel.taxText`, `$viewModel.currency`, etc.) directamente hacia controles nativos (`TextField`, `Picker`) de forma idiomática y con invalidaciones quirúrgicas de la vista.
  - [x] **Diseño Adaptativo con `ViewThatFits`**: Disponer los botones de propina (`0%`, `10%`, `15%`, `20%`, `Personalizada`) en una sola fila cuando hay espacio y conmutar a dos filas en pantallas compactas o tamaños grandes de Dynamic Type sin necesidad de `GeometryReader`.
  - [x] **Accesibilidad Apple HIG y VoiceOver**: Ocultar glifos decorativos (`Text("$").accessibilityHidden(true)`), unificar lecturas de pares etiqueta-valor con `.accessibilityElement(children: .combine)`, y garantizar áreas táctiles de 44x44 pt con `.contentShape(Rectangle())`.
  - [x] **Estilos Semánticos Puros de SwiftUI**: Utilizar `.background.secondary` y `.quaternary` en lugar de constructores de puente de UIKit (`UIColor`), asegurando compatibilidad multiplataforma y soporte automático para modo Claro y Oscuro.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ParticipantsSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ParticipantsSectionView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/TaxAndTipSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/TaxAndTipSectionView.swift)

### Task 3: Lista de Artículos, Acciones Rápidas y Editor Modal de Asignaciones (`ReceiptItemEditorSheet`)
- **Concepts learned**:
  - [x] **Gestión Segura de Hojas Modales (`.sheet(item:)` vs `.sheet(isPresented:)`)**: Usar `.sheet(item: $viewModel.activeItemDraft)` mantiene retenida la instancia del borrador durante la animación de descarte nativa de iOS, evitando el parpadeo de contenido vacío que ocurre al poner un `activeItemDraft = nil` sincrónicamente con `isPresented`.
  - [x] **Aritmética Entera Pura en la UI para Distribución Proporcional**: Calcular la proporción en vivo en modo `.portion` mediante `(shares * 100 + total / 2) / total` para mostrar porcentajes de referencia en la UI sin jamás invocar `Double` ni violar la regla de precisión monetaria.
  - [x] **Ajuste de Granularidad en Steppers de Porcentajes (`step: 1`)**: Los divisores impares (ej. 3 personas: 34%, 33%, 33%) requieren un incremento unitario (`step: 1`); un `step: 5` bloquearía al usuario impidiéndole alcanzar la suma obligatoria de 100%.
  - [x] **Flujo Accesible y Destructivo con Confirmación**: Implementar `.confirmationDialog` antes de eliminar artículos para evitar pérdidas accidentales de datos, acompañado de `ContentUnavailableView` con icono descriptivo cuando la lista está vacía.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptItemRowView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptItemRowView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptItemsSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptItemsSectionView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptItemEditorSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptItemEditorSheet.swift)

### Task 4: Tarjetas de Resumen por Persona, `ShareLink` y Espacio de Trabajo Unificado (`ReceiptWorkspaceView`)
- **Concepts learned**:
  - [x] **Síntesis Accesible vs. Combinación de Hijos (`accessibilityElement`)**: Cuando se sintetiza una narración gramatical completa (`accessibilityVoiceOverLabel`), el contenedor debe configurarse con `.accessibilityElement(children: .ignore)` para evitar que VoiceOver lea por duplicado tanto la oración personalizada como los elementos hijos.
  - [x] **Jerarquía y Contraste en Contenedores Anidados**: Al anidar tarjetas (`ReceiptWorkspaceView` → `sectionCard` → `ParticipantSummaryCardView`), transicionar de `.background.secondary` a `.background.tertiary` complementado con un borde fino (`strokeBorder(Color.secondary.opacity(0.2))`) preserva la profundidad visual y elevación en modo Claro y Oscuro.
  - [x] **Condición Quirúrgica para Guías de Estado Vacío**: Validar `splitResult != nil && !viewModel.items.isEmpty` garantiza que la UI muestre `emptyGuidanceView` mientras el usuario solo tenga participantes pero aún no haya registrado artículos, evitando badges de reconciliación en $0.00 prematuros.
  - [x] **Exportación Compartida Nativa (`ShareLink`) y Prevención de Pérdida de Datos**: Integrar `ShareLink` directamente con la cadena formateada `shareableSummaryText` sin puentes de UIKit (`UIActivityViewController`), y proteger el reseteo del recibo con diálogo de confirmación destructivo (`.confirmationDialog("¿Reiniciar cuenta?")`).
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ParticipantSummaryCardView.swift`](apps/SplitBill/SplitBill/UI/Views/ParticipantSummaryCardView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/SplitSummarySectionView.swift`](apps/SplitBill/SplitBill/UI/Views/SplitSummarySectionView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift)
  - [`apps/SplitBill/SplitBill/ContentView.swift`](apps/SplitBill/SplitBill/ContentView.swift)

## Milestone M3: Persistence (Receipts survive app restarts)

Status: Complete (3/3 tasks completed)

### Task 1: Capa de Infraestructura SwiftData, Mappers y `ReceiptStore` + Tests
- **Concepts learned**:
  - [x] **Desacoplamiento Estricto de Persistencia (`ADR-002`)**: El motor de dominio (`Receipt`, `Participant`, `SplitMode`, `Money`) no importa `SwiftData` ni `SwiftUI`. Las entidades `@Model` (`StoredReceipt`) residen exclusivamente en `Infrastructure/Persistence/`, preservando la inmutabilidad de los tipos de valor y aislando las reglas de negocio de la base de datos.
  - [x] **Preservación del Orden Canónico mediante DTOs en SwiftData**: Las relaciones relacionales nativas de SQLite (`@Relationship`) son conjuntos no ordenados que desordenan los arreglos al recargar. Serializar el grafo de participantes y artículos en un payload tipado (`ReceiptPayloadDTO`) dentro de `StoredReceipt` preserva el 100% del orden canónico de comensales, garantizando desempates de centavos deterministas con el Método de Hamilton en `SplitEngine`.
  - [x] **Captura Segura de Parámetros en `#Predicate`**: En macros `#Predicate` de SwiftData, capturar directamente rutas de propiedades externas (como `snapshot.id`) puede causar errores de compilación (`StandardPredicateExpression`). Extraer el identificador a una constante local (`let targetID = snapshot.id`) antes del predicado resuelve la captura de forma robusta.
  - [x] **Pruebas de Integración Aisladas en Memoria (`isStoredInMemoryOnly: true`)**: Configurar `ModelConfiguration(isStoredInMemoryOnly: true)` crea contenedores SQLite efímeros en RAM para cada `@Test` de Swift Testing, permitiendo validar round-trips completos, ordenamientos y operaciones CRUD en milisegundos sin contaminar el almacenamiento del dispositivo.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptStore.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptStore.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptPersistenceTests.swift`](apps/SplitBill/SplitBillTests/ReceiptPersistenceTests.swift)
  - [`scripts/verify.sh`](scripts/verify.sh)

### Task 2: Auto-Guardado, Restauración y Gestión de Cuentas en `ReceiptEditorViewModel`
- **Concepts learned**:
  - [x] **Patrón Reentrancy-Guard con `defer` en ViewModels `@Observable`**: Disparar persistencia automática desde observadores `didSet` en propiedades reactivas (`receiptTitle`, `taxText`, `tipSelection`, etc.) provocaría escrituras redundantes en cascada durante la carga de datos. El uso de una bandera transitoria `isRestoringSession = true` acompañada de `defer { isRestoringSession = false }` garantiza que la hidratación desde SQLite sea atómica y segura.
  - [x] **Compuerta Defensiva de Contenido (`hasContent`)**: Comprobar que existe al menos un título, participante o artículo antes de escribir en disco previene la creación de registros vacíos fantasma cuando el usuario simplemente abre la aplicación o inicia una cuenta en blanco.
  - [x] **Inyección de Dependencias Mediante Protocol Existentials**: Inyectar `(any ReceiptPersistenceStore)?` en el ViewModel en lugar de un contenedor concreto de SwiftData desacopla la UI de la base de datos, facilitando pruebas deterministas en memoria (`SwiftDataReceiptStore.inMemory()`) y compatibilidad transparente con SwiftUI Previews.
  - [x] **Ciclo de Vida de Cuentas y Fallback Determinista**: Al eliminar la cuenta activa, conmutar ordenadamente a la cuenta siguiente más reciente o generar una sesión limpia si era la última cuenta garantiza que la interfaz nunca quede en un estado huérfano.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptPersistenceTests.swift`](apps/SplitBill/SplitBillTests/ReceiptPersistenceTests.swift)

### Task 3: UI de Historial (`ReceiptHistorySheet`), Título de Cuenta e Integración en `MyApp`
- **Concepts learned**:
  - [x] **Inicialización Resiliente de Persistencia en `@main`**: Configurar `SwiftDataReceiptStore.live()` con fallback transparente a SQLite en memoria garantiza que fallos imprevistos de permisos en disco jamás provoquen un crash fatal al abrir la app.
  - [x] **Protección Contra Borrados Accidentales (`allowsFullSwipe: false`)**: Desactivar el borrado por deslizamiento completo en `swipeActions` exige una confirmación táctil deliberada sobre el botón "Eliminar", protegiendo los datos financieros del usuario.
  - [x] **Síntesis Accesible con Supresión de Hijos (`.accessibilityElement(children: .ignore)`)**: Generar una narración contextual completa para VoiceOver en las filas de historial evita lecturas fragmentadas de caracteres tipográficos decorativos (`•`).
  - [x] **Eliminación de Redundancias de Estado en la Barra de Herramientas**: Reemplazar acciones destructivas ambiguas ("Reiniciar") por un flujo claro de "Nueva Cuenta" con preservación en el historial garantiza coherencia conceptual con la persistencia automática de M3.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptHistorySheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptHistorySheet.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift)
  - [`apps/SplitBill/SplitBill/ContentView.swift`](apps/SplitBill/SplitBill/ContentView.swift)
  - [`apps/SplitBill/SplitBill/MyApp.swift`](apps/SplitBill/SplitBill/MyApp.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptStore.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptStore.swift)

### M3 Bugfix: Desbloqueo y Validación Reactiva en `ReceiptItemEditorSheet`
- **Concepts learned**:
  - [x] **Toolbar Item Scoping en SwiftUI vs. Estado Local (`@State`)**: Los elementos dentro de `.toolbar` en SwiftUI se renderizan a través de contenedores de navegación fuera del ciclo de actualización directo de la vista. Cuando un botón evalúa `.disabled(!isSaveEnabled)` contra propiedades de un modelo `@Observable` externo, los eventos de teclado en `TextField` pueden no invalidar la barra de herramientas a tiempo. Mantener un `@State` local para el borrador (`draft`) y hacer el botón siempre interactivo con validación imperativa elimina por completo esta fragilidad.
  - [x] **Validación Informativa sobre Deshabilitación Silenciosa (HIG de Apple)**: Deshabilitar botones de confirmación sin explicar el motivo genera fricción y confusión en el usuario. Permitir que el usuario toque "Guardar" y presentar inmediatamente un banner contextual con borde suave e ícono de advertencia explica con claridad qué dato falta (nombre vacío o importe inválido), guiando al usuario a la solución.
  - [x] **Limpieza Defensiva de Mensajes de Validación (`.onDisappear`)**: Garantizar que `viewModel.validationMessage = nil` al cerrarse la hoja modal (incluso mediante el gesto de arrastre hacia abajo) previene fugas de mensajes de error hacia otras vistas de la pantalla principal.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptItemEditorSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptItemEditorSheet.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptEditorViewModelTests.swift`](apps/SplitBill/SplitBillTests/ReceiptEditorViewModelTests.swift)

### M3 Enhancement: Pipeline CI/CD con GitHub Actions y Detección Dinámica de Entornos
- **Concepts learned**:
  - [x] **Autodetección Dinámica de Simuladores en CI**: En runners virtuales (GitHub Actions `macos-latest`), los nombres y versiones de simuladores varían según la imagen de Xcode preinstalada. Usar `xcrun simctl list devices available` con filtrado y selección de fallback evita fallos por dispositivos fijos hardcodeados (`iPhone 17` vs `iPhone 16`).
  - [x] **Compatibilidad de Deployment Target en Proyectos Swift 6**: Ajustar `IPHONEOS_DEPLOYMENT_TARGET` a `18.0` garantiza que el proyecto compile tanto en Xcode local moderno como en entornos de integración continua en la nube, manteniendo acceso a todas las APIs contemporáneas (`@Observable`, `SwiftData`, `Swift Testing`).
  - [x] **Guardia Estática de Invariantes Financieras en Pre-Commit / CI**: Incorporar un grep estático en `verify.sh` contra `Double` y `Float` en `apps/SplitBill/SplitBill/Domain/` convierte la política de dinero exacto en un bloqueo automatizado en cada Pull Request.
  - [x] **Optimización de Minutos de CI con Concurrencia**: Configurar `concurrency` con `cancel-in-progress: true` en GitHub Actions cancela inmediatamente ejecuciones redundantes de commits anteriores en la misma rama, optimizando el consumo de minutos de runners macOS.
- **Files implemented**:
  - [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
  - [`scripts/verify.sh`](scripts/verify.sh)
  - [`apps/SplitBill/SplitBill.xcodeproj/project.pbxproj`](apps/SplitBill/SplitBill.xcodeproj/project.pbxproj)
  - [`README.md`](README.md)

### CI Fix: Compatibilidad de APIs SwiftUI en iOS 18 y Visibilidad de Errores en CI
- **Concepts learned**:
  - [x] **Asimetría de Modales en SwiftUI (`.sheet(item:)` vs `.confirmationDialog`)**: Mientras que `.sheet(item:)` acepta un `Binding<Item?>`, la sobrecarga `.confirmationDialog(_:item:)` solo existe en SDKs muy recientes (Xcode 26/27). En iOS 18 (Xcode 16 en GitHub Actions `macos-latest`), `.confirmationDialog` requiere desacoplar visibilidad y payload con `isPresented: Binding<Bool>` + `presenting: T?`, garantizando compatibilidad retroactiva universal.
  - [x] **Visibilidad de Diagnósticos de Compilación (`-quiet` vs `> /dev/null`)**: Redirigir la salida estándar de `xcodebuild` a `/dev/null` oculta los errores detallados del compilador de Swift en CI. La bandera nativa `-quiet` mantiene la consola limpia durante compilaciones exitosas, pero expone inmediatamente el archivo, la línea y el diagnóstico de error exacto ante cualquier fallo.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptItemsSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptItemsSectionView.swift)
  - [`scripts/verify.sh`](scripts/verify.sh)

---

## M4 — Camera & Receipt Image Preview

Status: Completed (3/3 tasks completed)

### Task 1: Persistencia de Imagen, Normalización y Tickets de Muestra
- **Concepts learned**:
  - [x] **`@Attribute(.externalStorage)` en SwiftData**: Almacenar blobs binarios grandes (JPEG) directamente en las tablas B-tree de SQLite ralentiza las consultas de listado. Al anotarlo con `.externalStorage`, SwiftData mueve automáticamente los archivos binarios fuera de la base de datos hacia el sandbox de la app, manteniendo SQLite ultra liviano.
  - [x] **Normalización de Orientación EXIF con `UIGraphicsImageRenderer`**: Los sensores de cámara de smartphones guardan la orientación en metadatos EXIF sin rotar los píxeles reales. Re-dibujar el bitmap con `UIGraphicsImageRenderer` en orientación canónica `.up` garantiza que las futuras etapas de visión por computadora (OCR en M5) lean el texto horizontalmente sin fallos.
  - [x] **Tipos `nonisolated` en Concurrencia de Swift 6**: Declarar utilidades intensivas en CPU como `ReceiptImageProcessor` y `SampleReceiptImageGenerator` como `public nonisolated enum` permite su ejecución concurrente desde cualquier hilo o actor sin bloquear el `@MainActor` de la interfaz de usuario.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Imaging/ReceiptImageProcessor.swift`](apps/SplitBill/SplitBill/Infrastructure/Imaging/ReceiptImageProcessor.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Imaging/SampleReceiptImageGenerator.swift`](apps/SplitBill/SplitBill/Infrastructure/Imaging/SampleReceiptImageGenerator.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptImageTests.swift`](apps/SplitBill/SplitBillTests/ReceiptImageTests.swift)

### Task 2: Ciclo de Vida y Auto-Guardado en `ReceiptEditorViewModel`
- **Concepts learned**:
  - [x] **Compuerta de Auto-Guardado con Contenido de Imagen**: Al incluir `receiptImageData != nil` en la condición `hasContent`, una cuenta iniciada simplemente tomando una foto del ticket se persiste automáticamente en SQLite sin esperar a que el usuario ingrese texto.
  - [x] **Limpieza de Cuentas Huérfanas al Remover Imagen Única**: Si un usuario adjuntó una foto a una cuenta en blanco y luego la elimina, limpiar el registro huérfano de la base de datos evita que la foto eliminada "resucite" al relanzar la app.
  - [x] **Manejo Seguro de Errores Transaccionales en UI**: Validar y procesar los bytes entrantes antes de mutar el estado reactivo garantiza que ante datos corruptos se informe al usuario mediante `validationMessage` sin alterar la imagen previa.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptImageTests.swift`](apps/SplitBill/SplitBillTests/ReceiptImageTests.swift)

### Task 3: Captura con Cámara, Visor Zoomable e Integración en Workspace
- **Concepts learned**:
  - [x] **Privacidad Declarativa con `PhotosPicker` vs. Cámara con `UIViewControllerRepresentable`**: `PhotosPicker` opera fuera de proceso y otorga acceso exclusivo a la foto elegida sin solicitar acceso a toda la fototeca. Para la cámara, `CameraCaptureView` conecta `UIImagePickerController` verificando defensivamente `isCameraAvailable` para evitar excepciones en el simulador.
  - [x] **Composición Fluida de Gestos (`MagnifyGesture` + `DragGesture`)**: Combinar gestos simultáneos con acotación de desplazamiento (*clamping*) y doble toque permite inspeccionar recibos con fluidez nativa a 60/120 FPS sin redecodificar imágenes pesadas en cada frame del `body`.
  - [x] **Dianas Táctiles Accesibles (HIG de Apple)**: Asegurar áreas mínimas de interacción de 44x44 pt tanto en botones principales como secundarios (`.contentShape(Rectangle())`).
- **Files implemented**:
  - [`apps/SplitBill/SplitBill.xcodeproj/project.pbxproj`](apps/SplitBill/SplitBill.xcodeproj/project.pbxproj)
  - [`apps/SplitBill/SplitBill/UI/Views/CameraCaptureView.swift`](apps/SplitBill/SplitBill/UI/Views/CameraCaptureView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageViewerSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageViewerSheet.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptHistorySheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptHistorySheet.swift)

### Bugfix: Presentación de PhotosPicker dentro de Menús en SwiftUI
- **Concepts learned**:
  - [x] **Conflicto de Presentación de `PhotosPicker` dentro de `Menu`**: En SwiftUI (iOS 16+), incrustar un `PhotosPicker` directamente dentro de un elemento `Menu` hace que UIKit lo interprete como un elemento de menú ordinario (`UIAction`). Al hacer tap, el menú se cierra instantáneamente sin permitir que el recognizer de gestos interno de `PhotosPicker` presente el `PHPickerViewController`. El patrón idiomático y universal en SwiftUI es desacoplar el disparador de la presentación: usar un `Button { isPhotoPickerPresented = true }` dentro del menú y vincular la presentación en la vista raíz mediante el modificador `.photosPicker(isPresented:selection:matching:)`.
  - [x] **Prevención de Carreras y Feedback Visual en Procesamiento Asíncrono**: Deshabilitar los botones de acción y la miniatura mientras `isProcessingPhoto` es verdadero, junto a una superposición con `ProgressView`, previene toques dobles concurrentes y brinda retroalimentación accesible inmediata mientras se transfieren y normalizan los bytes de la imagen.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift)












