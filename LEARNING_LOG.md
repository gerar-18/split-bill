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

Status: In progress (Task 2/4 completed)

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

