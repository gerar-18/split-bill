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

---

## M5 — OCR: Image to Text with Evaluation Fixtures

Status: Completed (3/3 tasks completed)

### Task 1: Motor OCR con Vision y Reconstrucción Geométrica de Líneas
- **Concepts learned**:
  - [x] **Sistema de Coordenadas de Vision vs. UIKit/SwiftUI**: A diferencia de UIKit/SwiftUI (origen superior-izquierdo, $Y$ hacia abajo), el framework `Vision` de Apple sitúa el origen `(0, 0)` en la esquina **inferior izquierda** ($Y$ crece hacia arriba de `0.0` a `1.0`). Ordenar las observaciones por `midY` **descendente** es la clave matemática para ordenar las líneas de un ticket de arriba hacia abajo (orden de lectura natural).
  - [x] **Reconstrucción Espacial de Filas (*Row Clustering*)**: En recibos sin bordes, `VNRecognizeTextRequest` detecta el concepto a la izquierda (`"2x Tacos al Pastor"`) y el importe a la derecha (`"$170.00"`) como cajas independientes. Agruparlas considerando la proximidad vertical relativa a la altura de línea y ordenarlas horizontalmente por `minX` ascendente reconstruye líneas lógicas completas listas para el parsing de M6.
  - [x] **Concurrencia, Typed Throws y Rendimiento en Swift 6**: Ejecutar `VNImageRequestHandler` en segundo plano mediante `Task.detached` y mapear a `throws(ReceiptOCRError)` garantiza seguridad de tipos y fluidez de la interfaz. Evitar recomprimir a JPEG cuando ya se tiene un `CGImage` en memoria elimina artefactos y reduce la latencia de OCR a solo ~1.3 segundos.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRModels.swift`](apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRModels.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRService.swift`](apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRService.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptOCRTests.swift`](apps/SplitBill/SplitBillTests/ReceiptOCRTests.swift)

### Task 2: Persistencia de OCR, Integración en `ReceiptEditorViewModel` y Evaluation Fixtures
- **Concepts learned**:
  - [x] **Aislamiento Arquitectónico de Metadatos de Visión (`ADR-002`)**: `ocrRawText` se almacena en `ReceiptSnapshot` y `StoredReceipt` (persistencia) y se expone en `ReceiptEditorViewModel` (UI), pero el modelo puro `Receipt` y `SplitEngine` no se contaminan con texto no estructurado.
  - [x] **Guardián contra *Actor Reentrancy* en `@MainActor`**: En Swift Concurrency, `await` cede el control del actor. Capturar `let activeReceiptID = receiptID; let data = receiptImageData` y verificar `guard receiptID == activeReceiptID, receiptImageData == data else { return }` tras la llamada asíncrona de Vision evita que resultados obsoletos sobreescriban una cuenta nueva si el usuario cambió de sesión o reemplazó la imagen mientras el OCR estaba en vuelo.
  - [x] **Evaluation Fixtures Deterministas con Neural Engine**: Pruebas parametrizadas sobre presets sintéticos (`SampleReceiptPreset.allCases`) validando que el motor de Vision no solo reconozca texto, sino que agrupe con precisión geométrica el nombre del platillo y su precio en la misma línea lógica reconstruida (`ReceiptOCRLine.text`).
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/ReceiptSnapshot.swift)
  - [`apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift`](apps/SplitBill/SplitBill/Infrastructure/Persistence/StoredReceipt.swift)
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptOCREvaluationTests.swift`](apps/SplitBill/SplitBillTests/ReceiptOCREvaluationTests.swift)

### Task 3: UI de Inspección OCR (`ReceiptOCRTextSheet`) e Integración en `ReceiptImageSectionView`
- **Concepts learned**:
  - [x] **Semántica Visual vs. Ruido en VoiceOver en Texto Monoespaciado**: Al renderizar un ticket escaneado con líneas numeradas en fuente monoespaciada (`.font(.system(.footnote, design: .monospaced))`), ocultar el número visual a VoiceOver (`accessibilityHidden(true)`) permite que el lector de pantalla lea fluidamente cada línea del ticket sin insertar dígitos huérfanos entre cada descripción.
  - [x] **Flujo Asíncrono de Auto-Escaneo No Bloqueante en SwiftUI**: Disparar `Task { await viewModel.recognizeReceiptText() }` inmediatamente al adjuntar la imagen mientras `isProcessingPhoto` se libera en cuanto la imagen está en memoria permite que el usuario vea la foto al instante mientras el indicador de OCR corre en segundo plano.
  - [x] **Confirmación Accesible Multimodal (`AccessibilityNotification.Announcement`)**: Al copiar al portapapeles, combinar la actualización visual temporal con `AccessibilityNotification.Announcement("Texto copiado al portapapeles").post()` ofrece retroalimentación inmediata tanto visual como auditiva para usuarios de tecnologías de asistencia.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptOCRTextSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptOCRTextSheet.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift)

---

## CI/CD — Optimización del Pipeline de Verificación y Eliminación del Timeout del Simulador

Status: Completed

### Concepts learned:
- [x] **Diagnóstico del Timeout de 600s (10 min) en CoreSimulator (`IDETestOperationsObserverDebug`)**: En máquinas virtuales compartidas de GitHub Actions (`macos-latest`), ejecutar `xcodebuild test` contra un simulador frío/apagado provoca que el arranque en cascada de servicios de CoreSimulator compita con la inyección del ejecutable de prueba. `IDETestOperationsObserverDebug` de Xcode espera exactamente 600.0 segundos (10 minutos) antes de continuar o colgarse.
- [x] **Arranque Determinista de Simuladores con `xcrun simctl bootstatus -b` e Identificación por UUID (`id=${SIM_ID}`)**: En runners con múltiples runtimes de iOS, usar el nombre del simulador provoca ambigüedad (`WARNING: Using the first of multiple matching destinations`). Extraer el UUID exacto del simulador pre-arrancado y fijar `-destination "platform=iOS Simulator,id=${SIM_ID}"` garantiza que Xcode se conecte al simulador ya caliente sin lanzar una segunda instancia.
- [x] **Inanición del Pool Cooperativo de Swift Concurrency por APIs Síncronas**: Ejecutar operaciones intensivas de CPU/GPU como `VNImageRequestHandler.perform` dentro de `Task.detached` bloquea una hebra del pool fijo cooperativo de Swift 6 (igual al número de núcleos; solo 3 vCPUs en GitHub Actions). Encapsularlo con `withCheckedThrowingContinuation` hacia `DispatchQueue.global(qos: .userInitiated)` descarga el trabajo a la hebra de GCD liberando el pool cooperativo para no bloquear `Task.yield`, continuaciones y async/await.
- [x] **Inyección Canónica de Variables de Entorno en Pruebas con `TEST_RUNNER_<VAR>`**: En `xcodebuild`, las variables de entorno de la máquina no se transfieren automáticamente al ejecutable de prueba dentro del simulador. La documentación oficial de Apple especifica que el prefijo `TEST_RUNNER_` (ej. `TEST_RUNNER_CI=true`) es el estándar nativo para que `xcodebuild` inyecte la variable sin el prefijo dentro del proceso del test (`ProcessInfo.processInfo.environment["CI"]`).
- [x] **Hibernación del Host de Pruebas (`TEST_HOST`) en `MyApp.swift`**: Detectar `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil` permite omitir la inicialización persistente de SwiftData en disco y el renderizado completo de SwiftUI mientras la app sirve únicamente de contenedor para los tests unitarios.
- [x] **Pruebas de Redes Neuronales vs. Deterministas en VMs Headless (`.disabled(if:)` en Swift Testing)**: En runners de CI en la nube sin acelerador GPU Metal ni Apple Neural Engine, omitir llamadas pesadas a la red neuronal con `.disabled(if: ProcessInfo.processInfo.environment["CI"] != nil)` y complementarlas con pruebas de reconstrucción geométrica pura sobre presets sintéticos asegura que la lógica matemática se valide al 100% en milisegundos en cualquier entorno sin riesgo de cuelgues.

### Files modified:
- [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
- [`apps/SplitBill/SplitBill/MyApp.swift`](apps/SplitBill/SplitBill/MyApp.swift)
- [`apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRService.swift`](apps/SplitBill/SplitBill/Infrastructure/OCR/ReceiptOCRService.swift)
- [`apps/SplitBill/SplitBillTests/ReceiptOCRTests.swift`](apps/SplitBill/SplitBillTests/ReceiptOCRTests.swift)
- [`apps/SplitBill/SplitBillTests/ReceiptOCREvaluationTests.swift`](apps/SplitBill/SplitBillTests/ReceiptOCREvaluationTests.swift)
- [`scripts/verify.sh`](scripts/verify.sh)

---

## M6 — Intelligent Parsing: Del Texto OCR al Recibo Estructurado y Validado

Status: Completed (3/3 tasks completed)

### Task 1: Motor Determinista de Parsing (`DeterministicReceiptParser`) y Reconciliación Diagnóstica
- **Concepts learned**:
  - [x] **Arquitectura Determinista Primero vs. Dependencia de LLMs (ADR-003)**: Un parser determinístico basado en expresiones regulares y análisis posicional/semántico opera en <1 milisegundo, sin costo de inferencia, 100% offline, respetando la privacidad del usuario y garantizando resultados reproducibles. El diagnóstico de reconciliación matemática ($\sum \text{ítems} + \text{IVA} == \text{Total}$) actúa como árbitro objetivo infalible.
  - [x] **Lookbehind Semántico y Preservación de Centavos en Paquetes Indivisibles**: En líneas de detalle como `"(2 @ $85.00)"` o combos `"$100.00"` donde la división unitaria generaría centavos fraccionarios (ej. $33.3333$), el parser inspecciona la línea previa y valida que el total acumulado coincida exactamente con el precio entero en centavos, vinculando cantidad y precio unitario sin distorsionar el total.
  - [x] **Clasificación por Capas y Eliminación de Ruido**: Filtrado ordenado de separadores (`====`, `----`), encabezados de tabla (`CANT DESCRIPCION IMPORTE`), formas de pago/cambio (`EFECTIVO`, `CAMBIO`), metadatos (`RFC`, `FECHA`, `MESA`), líneas de resumen (`SUBTOTAL`, `IVA`, `PROPINA`, `TOTAL`) y líneas de platillos con cantidades prefijas/postfijas.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/Domain/MoneyParser.swift`](apps/SplitBill/SplitBill/Domain/MoneyParser.swift)
  - [`apps/SplitBill/SplitBill/Domain/ReceiptParser.swift`](apps/SplitBill/SplitBill/Domain/ReceiptParser.swift)
  - [`apps/SplitBill/SplitBill/Domain/DeterministicReceiptParser.swift`](apps/SplitBill/SplitBill/Domain/DeterministicReceiptParser.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptParserTests.swift`](apps/SplitBill/SplitBillTests/ReceiptParserTests.swift)

### Task 2: Modelo Borrador UI Human-in-the-Loop (`ParsedReceiptReviewDraft`) y Orquestación en `ReceiptEditorViewModel`
- **Concepts learned**:
  - [x] **Patrón Human-in-the-Loop como Guardián de Invariantes de Dominio (ADR-002)**: La visión por computadora y el OCR son inherentemente probabilísticos. En lugar de inyectar platillos no confirmados directamente al modelo `Receipt`, `ParsedReceiptReviewDraft` y `EditableParsedItemDraft` actúan como un buffer editable intermedio donde el usuario valida cantidades, nombres y precios.
  - [x] **Diagnóstico Reactivo en Tiempo Real**: Con el framework `Observation`, cada edición en el precio unitario, cantidad o toggle de inclusión recalcula en vivo el estado de reconciliación (`.verified`, `.discrepancy`, `.partial`), mostrando la diferencia exacta en centavos al usuario antes de importar.
  - [x] **Transacciones Seguras de Importación (Reemplazo vs. Suma)**: Ofrecer la opción de reemplazar o anexar platillos con asignación inicial en partes iguales (`.equal`) entre los comensales existentes, impidiendo la importación si la mesa no tiene comensales registrados.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/State/ParsedReceiptReviewDraft.swift`](apps/SplitBill/SplitBill/UI/State/ParsedReceiptReviewDraft.swift)
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`apps/SplitBill/SplitBillTests/ReceiptEditorViewModelParsingTests.swift`](apps/SplitBill/SplitBillTests/ReceiptEditorViewModelParsingTests.swift)

### Task 3: Interfaz Interactiva de Revisión (`ReceiptParsedReviewSheet`) e Integración en el Espacio de Trabajo
- **Concepts learned**:
  - [x] **Diseño Visual de Diagnóstico de Reconciliación**: Semáforo visual en la tarjeta superior con iconos semánticos (`checkmark.seal.fill` verde para totales verificados, `exclamationmark.triangle.fill` ámbar para discrepancias con importe exacto, `info.circle.fill` azul para tickets sin línea de total), proporcionando certeza matemática inmediata.
  - [x] **Flujo Rápido de Alta de Comensales Inline**: Detección del estado sin comensales (`viewModel.participants.isEmpty`) que presenta un banner interactivo inline con campo de texto y botón de adición directa, permitiendo al usuario registrar comensales sin necesidad de descartar la hoja de revisión ni perder su progreso de escaneo.
  - [x] **Áreas Táctiles Accesibles y Control Granular (Apple HIG)**: Steppers de cantidad con dianas táctiles mínimas de 44x44 pt, campos de precio formateados con teclado `.decimalPad` y visualización de la línea fuente del OCR para máxima trazabilidad.
  - [x] **Transiciones Suaves entre Hojas Modales en SwiftUI**: Desacoplar la presentación entre `ReceiptOCRTextSheet` y `ReceiptParsedReviewSheet` mediante un breve sleep asíncrono en `@MainActor` para permitir que UIKit complete la animación de descarte nativa antes de presentar la hoja de revisión, eliminando advertencias de presentación concurrente.
- **Files implemented**:
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptParsedReviewSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptParsedReviewSheet.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift)
  - [`apps/SplitBill/SplitBill/UI/Views/ReceiptOCRTextSheet.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptOCRTextSheet.swift)
  - [`apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift`](apps/SplitBill/SplitBill/UI/State/ReceiptEditorViewModel.swift)
  - [`LEARNING_LOG.md`](LEARNING_LOG.md)



---

## Roadmap & Architecture — Estrategia de Lanzamiento a App Store en 2 Olas (ADR-004) y Versionado Semántico

Status: Completed

### Concepts learned:
- [x] **Estrategia de Lanzamiento en Dos Olas (`v1.0 Local-First` vs. `v2.0 Cloud/Pro`)**: Publicar una versión inicial `Local-First` (nuevo hito `M6.5`) permite validar el ciclo completo en App Store Connect, TestFlight, firma y distribución con usuarios reales a $0 de costo de infraestructura y sin dependencias de red, antes de construir el backend en `M7`.
- [x] **Auditoría Preventiva de App Review Guidelines**: Identificación de puntos críticos de rechazo antes de escribir código:
  - **Packaging e Ícono (Guidelines 2.1 / 2.3.8 / 2.3.10)**: Evitar discrepancias de plataforma (`TARGETED_DEVICE_FAMILY = "1"` para iPhone en `v1.0`), incluir ícono 1024×1024 sin transparencia y alinear `developmentRegion = es`.
  - **Privacidad (Guideline 5.1.1(i))**: Requisito mandatorio de Privacy Manifest (`PrivacyInfo.xcprivacy`) y URL de Política de Privacidad y Soporte accesible tanto en la tienda como dentro de la aplicación.
  - **In-App Purchase (Guidelines 3.1.1 / 3.1.2)**: Funciones digitales avanzadas como extracción con LLM deben utilizar `StoreKit 2` con botón de restauración (`AppStore.sync()`) y enlaces legales.
  - **Privacidad en IA de Terceros (Guideline 5.1.2(i))**: Diálogo de consentimiento explícito previo a enviar datos del ticket a un modelo de lenguaje en la nube.
  - **Gestión de Cuentas (Guidelines 4.8 / 5.1.1(v))**: Si `M7` introduce cuentas, no bloquear el flujo local, ofrecer *Sign in with Apple* y proveer eliminación de cuenta in-app con revocación criptográfica de tokens.
- [x] **Trazabilidad Git Profesional con Versionado Semántico**: Sincronizar los tags anotados de Git (`v0.6.0`, `v1.0.0-rc.N`, `v1.0.0`) con `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION` de Xcode, automatizando la verificación en CI para tags `v*` y publicando releases estructurados en GitHub.

### Files modified:
- [`docs/product/roadmap.md`](docs/product/roadmap.md)
- [`docs/product/vision.md`](docs/product/vision.md)
- [`docs/architecture/system.md`](docs/architecture/system.md)
- [`docs/decisions/ADR-003-ai-after-deterministic-parser.md`](docs/decisions/ADR-003-ai-after-deterministic-parser.md)
- [`docs/decisions/ADR-004-appstore-release-strategy.md`](docs/decisions/ADR-004-appstore-release-strategy.md)
- [`.agents/skills/git-workflow/SKILL.md`](.agents/skills/git-workflow/SKILL.md)
- [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
- [`README.md`](README.md)

---

## M6.5 — App Store v1.0 Release Readiness (Local-First)

Status: Completed (4/4 tasks completed)

### Concepts learned:
- [x] **App Privacy Manifest (`PrivacyInfo.xcprivacy`) en Xcode**: La inclusión del manifiesto oficial con `NSPrivacyTracking = false`, dominios vacíos y sin recopilación de datos fuera del dispositivo cumple con la Guideline 5.1.1(i) de Apple y permite que App Store Connect genere la etiqueta de privacidad estática ("Data Not Collected") sin advertencias de subida.
- [x] **Declaración Automática de Exención de Cifrado (`ITSAppUsesNonExemptEncryption = NO`)**: Incluir la clave en el `Info.plist` generado vía Build Settings elimina el diálogo manual de cumplimiento de exportación de EE. UU. en cada build enviada a TestFlight y App Store.
- [x] **Requisitos Físicos del Ícono Maestro de App Store (`AppIcon.png` 1024×1024 px)**: Apple prohíbe estrictamente canales alfa (transparencia) en el ícono de la tienda para que el sistema operativo aplique el recorte dinámico (*squircle*) sin artefactos visuales. Se validó con `sips -g hasAlpha` (`hasAlpha: no`) y se activó `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- [x] **Alineación de Plataforma e Idioma de Revisión (`developmentRegion = es`)**: Fijar `TARGETED_DEVICE_FAMILY = 1` restringe el lanzamiento a iPhone, eliminando la exigencia de capturas de iPad de 13" y revisiones de visión espacial en iPadOS/visionOS. Cambiar la región a español evita que la App Store clasifique erróneamente la app como disponible solo en inglés.
- [x] **Transparencia Legal In-App y Desacoplamiento de Metadatos (`AppMetadata` & `AboutPrivacySheet`)**: Proporcionar acceso directo desde la interfaz a la versión y a URLs públicas sobre HTTPS con la Política de Privacidad y el Soporte técnico cumple con las Guidelines 1.5 y 5.1.1(i), sin almacenar credenciales ni depender de APIs de red externas.
- [x] **Pruebas Automatizadas de Cumplimiento de Empaquetado (`AppBundleComplianceTests`)**: Uso de `Swift Testing` para verificar en tiempo de compilación y CI que el `PrivacyInfo.xcprivacy`, las claves de `Info.plist` y los enlaces legales se mantengan válidos e inmutables en futuras versiones.

### Files modified / created:
- [`apps/SplitBill/SplitBill.xcodeproj/project.pbxproj`](apps/SplitBill/SplitBill.xcodeproj/project.pbxproj)
- [`apps/SplitBill/SplitBill/PrivacyInfo.xcprivacy`](apps/SplitBill/SplitBill/PrivacyInfo.xcprivacy)
- [`apps/SplitBill/SplitBill/Assets.xcassets/AppIcon.appiconset/Contents.json`](apps/SplitBill/SplitBill/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [`apps/SplitBill/SplitBill/Assets.xcassets/AppIcon.appiconset/AppIcon.png`](apps/SplitBill/SplitBill/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
- [`apps/SplitBill/SplitBill/UI/State/AppMetadata.swift`](apps/SplitBill/SplitBill/UI/State/AppMetadata.swift)
- [`apps/SplitBill/SplitBill/UI/Views/AboutPrivacySheet.swift`](apps/SplitBill/SplitBill/UI/Views/AboutPrivacySheet.swift)
- [`apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptWorkspaceView.swift)
- [`apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift`](apps/SplitBill/SplitBill/UI/Views/ReceiptImageSectionView.swift)
- [`apps/SplitBill/SplitBillTests/AppBundleComplianceTests.swift`](apps/SplitBill/SplitBillTests/AppBundleComplianceTests.swift)
- [`docs/legal/privacy.md`](docs/legal/privacy.md)
- [`docs/legal/support.md`](docs/legal/support.md)
- [`docs/release/appstore-v1-checklist.md`](docs/release/appstore-v1-checklist.md)

---

## M6.6 — Portfolio & Open-Source Showcase (v1.0.0)

Status: Completed (4/4 tasks completed)

### Concepts learned:
- [x] **Construcción de un Repositorio Insignia de Portafolio**: Cómo estructurar un README ejecutivo que hable directamente a reclutadores y líderes de ingeniería en los primeros segundos: badges oficiales, capturas visuales de alta fidelidad, tabla de destacados de código (*deep-links* a `Domain/`, `Infrastructure/` y `UI/`) y demostración de principios arquitectónicos sólidos (`ADR-002`).
- [x] **Sideloading Gratuito en Dispositivos Físicos con Personal Team de Xcode ($0 Costo)**: Comprender que la membresía anual del Apple Developer Program ($99 USD/año) solo es necesaria para publicar en la tienda o TestFlight público; cualquier desarrollador puede firmar localmente sus aplicaciones usando su Apple ID personal gratuito (*Personal Team*) e instalarlas vía USB/Wi-Fi en hasta 3 dispositivos personales sin costo alguno.
- [x] **Documentación de Historial con Keep a Changelog y SemVer**: Adopción formal de `CHANGELOG.md` estructurado desde `v0.1.0` hasta `v1.0.0`, ofreciendo trazabilidad completa de cada hito y funcionalidad entregada.
- [x] **Licenciamiento Open-Source (MIT)**: Inclusión de la licencia MIT permisiva para habilitar a la comunidad y evaluadores técnicos a inspeccionar, clonar y aprender del código fuente libremente.

### Files modified / created:
- [`LICENSE`](LICENSE)
- [`CHANGELOG.md`](CHANGELOG.md)
- [`.gitignore`](.gitignore)
- [`README.md`](README.md)
- [`docs/assets/app-icon-preview.png`](docs/assets/app-icon-preview.png)
- [`docs/assets/01-workspace.png`](docs/assets/01-workspace.png)
- [`docs/product/roadmap.md`](docs/product/roadmap.md)
