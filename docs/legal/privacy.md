# Política de Privacidad — SplitBill / Privacy Policy

*Última actualización: 6 de noviembre de 2026 / Last updated: November 6, 2026*

---

## Español

Esta Política de Privacidad describe cómo **SplitBill** ("la aplicación", "nosotros") trata la información de los usuarios al utilizar nuestra aplicación para iOS.

### 1. Compromiso Local-First y Cero Recolección de Datos
SplitBill fue diseñada desde sus cimientos bajo una arquitectura **Local-First** (primeramente local). En la versión actual (`v1.0`):
- **No recopilamos, almacenamos ni transmitimos datos personales fuera de tu dispositivo.**
- **No creamos identificadores persistentes de usuario.**
- **No utilizamos kits de desarrollo (SDKs) de publicidad ni de rastreo (*tracking*).**
- El parámetro de rastreo de privacidad de Apple está declarado explícitamente como `NSPrivacyTracking = false`.

### 2. Uso de Permisos del Sistema
- **Cámara (`NSCameraUsageDescription`)**: SplitBill solicita acceso a la cámara exclusivamente para permitirte tomar fotografías de recibos y tickets de restaurantes en el momento. Las fotos capturadas se procesan en la memoria de tu dispositivo y se almacenan únicamente en la base de datos local (`SwiftData`) de tu iPhone. No se envían a ningún servidor ni servicio en la nube.
- **Fototeca / Fotos**: Al seleccionar una foto existente, SplitBill utiliza el selector nativo fuera de proceso del sistema (`PhotosPicker` de Apple). La aplicación únicamente recibe la imagen que selecciones voluntariamente y nunca tiene acceso general a tu biblioteca de fotos.
- **Reconocimiento de Texto (OCR)**: La extracción de texto de los tickets se realiza por defecto completamente en el dispositivo utilizando el framework `Vision` y el motor neuronal local de Apple (`Neural Engine`).

### 2.1 Uso Opcional de Inteligencia Artificial (Extracción Asistida)
SplitBill ofrece una función opcional de estructuración de recibos asistida por Inteligencia Artificial. En estricto apego a la directriz 5.1.2(i) de Apple:
- **Consentimiento Previo e Informado**: Ningún dato se envía a servicios de IA sin que el usuario otorgue consentimiento explícito mediante una pantalla informativa previa.
- **Minimización de Datos**: Únicamente se envía el texto ya reconocido (OCR) y la moneda de la cuenta. **Nunca se transmiten fotografías del recibo, ubicación, contactos ni identificadores personales.**
- **No Entrenamiento**: Los datos enviados se procesan exclusivamente para retornar la lista estructurada de platillos e importes y no son utilizados para entrenar modelos de IA de terceros.
- **Revocabilidad**: El usuario puede revocar este consentimiento en cualquier momento desde la sección *Acerca de y Privacidad*.

### 2.2 Colaboración Temporal en Tiempo Real (Cuentas Compartidas)
Cuando el anfitrión decide voluntariamente compartir una cuenta mediante código QR o enlace (`splitbill://` / `https://splitbill.app/join`):
- **Sin Cuentas Obligatorias**: Ni el anfitrión ni los invitados necesitan registrarse ni iniciar sesión. Los invitados únicamente ingresan un nombre temporal visible solo dentro de la sesión activa.
- **Privacidad de Imagen por Defecto (Opt-In)**: La fotografía del recibo **NO se sube por defecto**. Únicamente se transmite si el anfitrión activa explícitamente la casilla opcional de compartir imagen del recibo.
- **Tokens Efímeros y Expiración**: El acceso se controla mediante tokens aleatorios de sesión guardados en el Llavero de Apple con atributo `ThisDeviceOnly` (sin respaldo en iCloud). Las sesiones caducan automáticamente en 24 horas o al cerrarse por el anfitrión.
- **Controles de Seguridad y Moderación (Guideline 1.2)**: Cualquier participante puede ocultar localmente la imagen del recibo, reportar contenido inapropiado (poniendo la sesión en cuarentena automática ante múltiples reportes) o bloquear y abandonar la sesión de inmediato.

### 3. Almacenamiento Local y Eliminación
Toda la información registrada (nombres de comensales, importes, propinas y fotos de recibos) se almacena únicamente en tu iPhone. Puedes eliminar cualquier recibo o foto en cualquier momento directamente desde la aplicación con el botón de papelera, o eliminar todos los datos desinstalando la aplicación.

### 4. Menores de Edad
La aplicación no recopila información personal de ninguna persona, incluidos menores de edad.

### 5. Cumplimiento Legal (LFPDPPP México y GDPR)
Dado que SplitBill no almacena ni procesa datos personales en servidores externos, no existe transferencia de datos a terceros. Para cualquier duda respecto al ejercicio de derechos ARCO o consultas sobre privacidad, puedes contactarnos directamente.

### 6. Contacto
Si tienes preguntas sobre esta Política de Privacidad, puedes escribir a:
- **Correo electrónico:** `gl815465@gmail.com`
- **Repositorio:** [github.com/gerar-18/split-bill](https://github.com/gerar-18/split-bill)

---

## English

This Privacy Policy explains how **SplitBill** ("the app", "we") handles user data when you use our iOS application.

### 1. Local-First Architecture & Zero Data Collection
SplitBill is built from the ground up on a strict **Local-First** model. In the current release (`v1.0`):
- **We do not collect, store, transmit, or sell personal data off your device.**
- **No user accounts or identifiers are created or tracked.**
- **No third-party advertising or analytics SDKs are bundled.**
- Apple's Privacy Tracking declaration is set to `NSPrivacyTracking = false`.

### 2. Device Permissions
- **Camera (`NSCameraUsageDescription`)**: Used strictly to photograph physical restaurant receipts. Captured photos are processed locally on-device and stored only in your local iPhone storage (`SwiftData`). No images are uploaded to any external server.
- **Photo Library**: Selected via Apple's out-of-process `PhotosPicker`. The app only accesses the specific image you voluntarily choose, without general photo library access.
- **On-Device OCR**: Optical Character Recognition uses Apple's native `Vision` framework running locally on your iPhone's Neural Engine.

### 2.1 Optional AI-Assisted Extraction
SplitBill offers an optional AI-assisted receipt structuring feature. In strict compliance with Apple Review Guideline 5.1.2(i):
- **Prior Informed Consent**: No data is transmitted to AI services without explicit prior user consent via an informative prompt.
- **Data Minimization**: Only the recognized OCR text and currency code are sent. **Receipt photographs, location, contacts, and personal identifiers are never transmitted.**
- **No Model Training**: Transmitted data is used exclusively to parse items and prices for the active receipt session and is never used to train third-party AI models.
- **Revocable Anytime**: Users can revoke AI consent at any time directly in the in-app *About & Privacy* sheet.

### 2.2 Temporary Real-Time Shared Receipts
When a host explicitly chooses to share a receipt via QR code or invite link (`splitbill://` / `https://splitbill.app/join`):
- **No Forced Accounts**: Neither hosts nor guests are required to register or sign in. Guests provide only a temporary display name scoped to the active shared receipt.
- **Privacy-First Image Sharing (Opt-In Only)**: Receipt photos are **excluded by default**. Images are uploaded only if the host explicitly enables the opt-in toggle when creating the session.
- **Ephemeral Tokens & TTL**: Session participation relies on random capability tokens stored in Apple Keychain with `ThisDeviceOnly` accessibility. Sessions expire automatically after 24 hours or immediately when closed by the host.
- **User-Generated Content Moderation (Guideline 1.2)**: Participants can locally hide any shared receipt image, submit categorized abuse reports (triggering automatic server quarantine after threshold reports), or permanently block and leave a session with a single confirmation.

### 3. Data Retention and Deletion
All participants, amounts, and receipt photos reside strictly on your physical device. You can delete any receipt inside the app at any time, or purge all data by uninstalling the application.

### 4. Contact
For any privacy questions or requests, please reach out to:
- **Email:** `gl815465@gmail.com`
- **Repository:** [github.com/gerar-18/split-bill](https://github.com/gerar-18/split-bill)
