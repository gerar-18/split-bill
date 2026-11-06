# Guía y Checklist de Lanzamiento — App Store Connect (v1.0.0)

Esta guía contiene todos los textos, configuraciones y datos necesarios para configurar y enviar **SplitBill v1.0.0** a revisión en **App Store Connect** sin fricción.

---

## 1. Ficha de la Aplicación en App Store Connect

| Campo | Valor Recomendado | Límite / Formato |
|---|---|---|
| **Nombre de la App** | `SplitBill — Dividir Cuentas` | 27 / 30 caracteres |
| **Subtítulo** | `Divide tickets sin errores` | 26 / 30 caracteres |
| **Categoría Primaria** | `Finanzas` (*Finance*) | Obligatoria |
| **Categoría Secundaria** | `Utilidades` (*Utilities*) | Opcional |
| **Idioma Principal** | `Español (México)` o `Español` | Coincide con `developmentRegion = es` |
| **Bundle ID** | `com.gerar18.SplitBill` | Registrado en Apple Developer |
| **SKU** | `SPLITBILL-IOS-01` | Identificador interno único |
| **URL de Privacidad** | `https://github.com/gerar-18/split-bill/blob/main/docs/legal/privacy.md` | `HTTP 200` público |
| **URL de Soporte** | `https://github.com/gerar-18/split-bill/blob/main/docs/legal/support.md` | `HTTP 200` público |
| **URL de Marketing** | `https://github.com/gerar-18/split-bill` | Opcional |

### Palabras Clave (*Keywords* — máx 100 caracteres)
```text
dividir cuenta,ticket,recibo,propina,restaurante,split bill,gastos,amigos,finanzas,ocr
```

### Descripción de la App
```text
Dividir la cuenta en restaurantes nunca fue tan fácil, rápido y exacto. Con SplitBill olvídate de las calculadoras y de los centavos perdidos:

• ESCANEO INTELIGENTE ON-DEVICE: Fotografía tu ticket físico o selecciónalo de tu galería. El motor óptico (OCR) detecta platillos y precios directamente en tu iPhone.
• 4 MODOS DE DIVISIÓN: Divide platillos en partes iguales, porcentajes exactos, montos fijos o porciones entre cualquier combinación de comensales.
• MATEMÁTICA FINANCIERA SIN REDONDEOS: Calculado con el Método de Hamilton en centavos enteros para que el total pagado cuadre exactamente al centavo.
• IMPUESTOS Y PROPINAS TRANSPARENTES: Elige propina recomendada (10%, 15%, 20%) o personalizada y distribúyela de forma proporcional o equitativa.
• HISTORIAL Y ZOOM INTEGRADO: Tus cuentas se guardan automáticamente para consultarlas cuando quieras, con visor de ticket a pantalla completa.
• 100% PRIVADO Y LOCAL: Tus fotos y cuentas nunca salen de tu iPhone. Sin registros obligatorios, sin publicidad y sin conexión a internet requerida.
```

---

## 2. Información para el Revisor de Apple (*App Review Information*)

> [!TIP]
> Copia este texto exactamente en la sección **App Review Notes** de App Store Connect para evitar demoras o solicitudes de aclaración:

```text
Estimado equipo de App Review,

SplitBill es una aplicación 100% Local-First que opera en su totalidad dentro del dispositivo, sin requerir cuentas de usuario, inicio de sesión ni servicios externos de backend.

Para probar la funcionalidad completa del flujo:
1. Al abrir la app, en la sección "Foto del Recibo", pueden tomar una fotografía de un ticket real con la cámara o tocar el botón "Muestra" para cargar tickets sintéticos de demostración incluidos en la aplicación.
2. El reconocimiento de texto (OCR) con Apple Vision extraerá los platillos automáticamente.
3. Toquen "Revisar e importar" para confirmar los platillos detectados.
4. En la sección "Participantes", agreguen comensales (ej. Ana, Carlos) y asignen platillos tocando sobre ellos.
5. Observen el desglose exacto por comensal en la tarjeta de resumen final y prueben el botón "Compartir" para exportar el texto.
6. En la barra superior, el botón (i) abre la ventana "Acerca de y Privacidad" con los enlaces directos a nuestra Política de Privacidad y Soporte.

Contacto técnico en caso de preguntas: gl815465@gmail.com
```

---

## 3. Cuestionarios Obligatorios de App Store Connect

### Clasificación por Edad (*Age Rating*)
- Contenido web sin filtrar: **No**
- Apuestas o concursos: **No**
- Acceso a ubicación o redes sociales: **No**
- Violencia, drogas o contenido adulto: **No**
- **Resultado esperado:** Clasificación **4+** (apta para todo público).

### Etiquetas de Privacidad de la App (*App Privacy Nutrition Labels*)
- Seleccionar: **"No, no recopilamos datos en esta app"** (*Data Not Collected*).
- *Justificación*: SplitBill v1.0 opera 100% en el dispositivo con `NSPrivacyTracking = false`.

### Cumplimiento de Exportación (*Export Compliance*)
- La configuración `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` ya está incluida en el proyecto, por lo que App Store Connect no pedirá responder el cuestionario de criptografía en cada subida.

---

## 4. Generación de Capturas de Pantalla (iPhone 6.9")

Apple exige capturas de **iPhone de 6.9"** (resolución `1320 × 2868` o `1290 × 2796` px, como iPhone 16 Pro Max / 17 Pro Max):

```bash
# 1. Ejecutar simulador iPhone 17 / iPhone 16 Pro Max
xcrun simctl boot "iPhone 17"

# 2. Tomar capturas directamente desde la terminal
xcrun simctl io booted screenshot screenshot_01_workspace.png
xcrun simctl io booted screenshot screenshot_02_review.png
xcrun simctl io booted screenshot screenshot_03_summary.png
xcrun simctl io booted screenshot screenshot_04_about.png
```
