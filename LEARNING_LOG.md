# Learning Log

## M0 — Engineering Foundation

Status: Completed

### Concepts learned
- [x] **Git en Monorepos y proyectos Xcode**: Por qué ocurre el problema de *Embedded Git Repository* cuando Xcode inicializa su propio `.git` en subcarpetas (`apps/SplitBill/.git`), cómo resolverlo y la importancia de ignorar `xcuserdata/` para evitar colisiones de estado personal en equipos.
- [x] **Estructura moderna de proyectos Xcode**: Comprensión de `PBXFileSystemSynchronizedRootGroup` (novedad en Xcode 16+ para sincronizar archivos en disco automáticamente) y por qué archivos con nombres duplicados (como `.gitkeep`) provocan errores de recursos duplicados (`CpResource`).
- [x] **Swift Testing vs XCTest**: Adopción del estándar moderno de pruebas en Swift 6 (`import Testing`, macros `@Test`, aserciones contextuales con `#expect`) en lugar del legado basado en clases de Objective-C (`XCTestCase`).
- [x] **Configuración de Schemes Compartidos (`xcshareddata`)**: Creación de esquemas reproducibles en `SplitBill.xcscheme` para permitir que herramientas CLI (`xcodebuild`) y agentes ejecuten suites de pruebas sin depender de la UI de Xcode.
- [x] **Guardrails de Arquitectura en CI/CLI**: Automatización con [`scripts/verify.sh`](../scripts/verify.sh) para verificar de forma estática que la capa de Dominio nunca importe SwiftUI ([ADR-002](../docs/decisions/ADR-002-domain-separation.md)) antes de compilar y correr pruebas.
- [x] **Antigravity agents y skills**: Comprensión del sistema de especialización de agentes ([`.agents/agents/`](../.agents/agents)) y ejecución de flujos de verificación guiados.

### Agent contribution
- Diagnóstico del repositorio embebido de Git y corrección de `.gitignore`.
- Configuración del target de pruebas `SplitBillTests` en `project.pbxproj` vinculado con el framework moderno *Swift Testing*.
- Creación del esquema compartido `SplitBill.xcscheme` habilitando el target de pruebas en el *TestAction*.
- Creación y verificación del script reproducible [`scripts/verify.sh`](../scripts/verify.sh).
- Ejecución exitosa de compilación y pruebas en el simulador de iPhone 17.

### Human understanding
- M0 establece las bases para trabajar de manera iterativa y profesional: cada cambio que haga el desarrollador o el agente puede validarse en segundos con `./scripts/verify.sh`.
- La separación entre `Domain` y `UI` se respeta desde la infraestructura de compilación antes de escribir las reglas de división de cuentas en M1.

### Open questions
- En M1 definiremos la representación exacta del tipo `Money` (modelado con enteros en centavos + ISO Currency) y la estrategia de redondeo para división equitativa de centavos.
