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



