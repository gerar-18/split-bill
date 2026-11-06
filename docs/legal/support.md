# Asistencia y Soporte de SplitBill / SplitBill Support

*Última actualización: 6 de noviembre de 2026 / Last updated: November 6, 2026*

Bienvenido a la página oficial de asistencia y soporte para **SplitBill** (iOS). Cumpliendo con los lineamientos de Apple App Store (Guideline 1.5), aquí encontrarás vías de contacto directas y respuestas a las preguntas más frecuentes.

---

## 📬 Canales de Contacto

Si experimentas algún problema con la aplicación, tienes sugerencias o requieres asistencia técnica:
- **Correo electrónico de soporte directo:** [gl815465@gmail.com](mailto:gl815465@gmail.com)
  *(Tiempo de respuesta estimado: menos de 24–48 horas hábiles).*
- **Seguimiento de problemas en GitHub:** [github.com/gerar-18/split-bill/issues](https://github.com/gerar-18/split-bill/issues)

---

## ❓ Preguntas Frecuentes (FAQ)

### 1. ¿Cómo escaneo un ticket de restaurante?
1. En la pantalla principal, dirígete a la sección **"Foto del Recibo"**.
2. Toca **"Cámara"** para fotografiar el recibo físico o **"Galería"** para elegir una foto guardada.
3. El motor de reconocimiento óptico (OCR) analizará automáticamente las líneas de texto del ticket en segundo plano.
4. Toca **"Revisar e importar"** para confirmar las cantidades, nombres y precios antes de agregarlos a tu cuenta.

### 2. ¿Mis fotos o cuentas se envían a algún servidor?
**No.** SplitBill opera 100% de forma local en tu iPhone (*Local-First*). Las fotos, el OCR de Apple Vision y tu historial se procesan y almacenan únicamente en la memoria y almacenamiento de tu dispositivo. Ningún dato sale a la nube ni a terceros.

### 3. ¿Cómo funciona la división de centavos e impuestos?
SplitBill utiliza el **Método de Hamilton (o método del resto mayor)** con aritmética de enteros en centavos menores (`Int64`). Esto significa que:
- No existen errores de redondeo por números flotantes (`Double`/`Float`).
- Los centavos indivisibles de impuestos y propinas se asignan equitativa y determinísticamente, garantizando que la suma exacta de lo que paga cada persona coincida al centavo con el total del ticket.

### 4. ¿Cómo elimino una cuenta o foto guardada?
- **Para una foto:** Toca el botón *"Eliminar foto"* dentro de la sección de foto.
- **Para una cuenta del historial:** Toca el icono de historial (reloj con flecha) en la esquina superior izquierda, desliza hacia la izquierda sobre la cuenta que deseas borrar y confirma la eliminación.
- **Para borrar todo:** Al desinstalar la app de tu iPhone, se eliminan permanentemente todos los datos almacenados.

### 5. ¿Qué requisitos de sistema tiene la aplicación?
SplitBill requiere **iOS 18.0 o posterior** en dispositivos iPhone compatibles.

---

## English Summary

For help, feedback, or bug reports regarding SplitBill:
- **Direct Email Support:** [gl815465@gmail.com](mailto:gl815465@gmail.com)
- **Issue Tracker:** [github.com/gerar-18/split-bill/issues](https://github.com/gerar-18/split-bill/issues)
- **Privacy:** 100% offline and on-device processing. No accounts, no servers, zero telemetry tracking.
