<p align="center">
  <img src="assets/images/logo_cat_strawberry.png" alt="Nutrifoto AI" width="140"/>
</p>

<h1 align="center">Nutrifoto AI</h1>

<p align="center">
  <strong>Computer Vision × Nutrición Inteligente</strong><br>
  <sub>Detección de alimentos on-device con YOLO26, coaching nutricional con Gemini y un motor de descubrimiento de recetas multi-fuente — todo en una app móvil con UI Glassmorphism premium.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.11-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/YOLO26-Custom%20Model-FF6F00?style=for-the-badge&logo=pytorch&logoColor=white" alt="YOLO26"/>
  <img src="https://img.shields.io/badge/Gemini-3.1%20Flash-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Gemini"/>
  <img src="https://img.shields.io/badge/Groq-Llama%203.3-F68B1F?style=for-the-badge&logo=meta&logoColor=white" alt="Groq"/>
  <img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <a href="#-pruébala-ahora"><strong>Probar »</strong></a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#-descripción"><strong>Descripción »</strong></a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#-arquitectura"><strong>Arquitectura »</strong></a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#-data-science--entrenamiento"><strong>Data Science »</strong></a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#-instalación"><strong>Instalación »</strong></a>
</p>

---

## 📱 Pruébala Ahora

> **¿Eres reclutador?** Prueba la app en 30 segundos sin configurar nada:

| Canal | Enlace |
| :--- | :--- |
| 📦 **APK Directo** | [Descargar última release](https://github.com/Paimilla/nutrifoto/releases) |
| 🎬 **Video Demo** | [Ver Video en YouTube](https://youtu.be/Papv_p2c90o?si=4MR1eUosuUuBJtQS) |
| 🌐 **Appetize.io** | [Abrir en navegador](https://appetize.io/app/b_gockvto6qiz4mdnfkatflaezui) (emulador Android real) |

---

## 📖 Descripción

**Nutrifoto AI** es un ecosistema integral que demuestra el potencial de la **visión artificial aplicada a la salud**. Diseñé y entrené un modelo **YOLO26** con un dataset propio curado de **30 clases de comida chilena**, permitiendo detección on-device precisa y fluida.

```
📸 Foto → 🧠 YOLO26 → 🍗 "Pollo asado" → 📊 250 kcal / 31g prot → ✅ Registrado
```

> [!TIP]
> **Video Completo**: Puedes ver el funcionamiento de la app en acción en este [Video de YouTube](https://youtu.be/Papv_p2c90o?si=4MR1eUosuUuBJtQS).

<details>
<summary><strong>🎞️ Guion de la Demo (Walkthrough)</strong></summary>

| Fase | Tiempo | Funcionalidad |
| :--- | :--- | :--- |
| **Intro** | 00–10s | Splash screen → Dashboard principal con UI Glassmorphism |
| **IA Vision** | 10–25s | Escaneo en tiempo real con **YOLO26** · Detección múltiple |
| **Barcode** | 25–35s | Escaneo de productos vía **OpenFoodFacts** |
| **Voice AI** | 35–50s | Registro por voz procesado por **Groq** (NLP) |
| **Analytics** | 50–60s | Dashboard interactivo con `fl_chart` · Gestión de metas |

</details>

### 🌟 ¿Por qué destaca este proyecto?

| Problema Real | Solución Técnica |
| :--- | :--- |
| Registrar comida es tedioso y lento | 📸 **Camera-First**: una foto = registro completo con macros |
| Las apps solo conocen comida anglosajona | 🇨🇱 **30 clases chilenas** entrenadas con dataset propio en YOLO26 |
| No hay contexto nutricional personalizado | 🤖 **Gemini + Groq**: coaching dinámico basado en macros restantes |
| El modelo puede fallar sin internet | 🧠 **Motor híbrido**: YOLO26 on-device + fallback de análisis cromático |
| Los scanners de barras no muestran macros | 📦 **OpenFoodFacts** integrado con datos nutricionales completos |
| Las recetas vienen de una sola fuente | 🔀 **Cascade multi-API**: Edamam + Spoonacular + OpenFoodFacts + DB local |

---

## ✨ Características Principales

### 🎯 Motor de Visión Híbrido
Detección **YOLO26 float16** on-device (~120ms en Pixel 7) con fallback de análisis cromático para asegurar resultados incluso en condiciones difíciles.

### 🍳 Motor de Recetas Multi-Fuente
Sistema de búsqueda inteligente que combina **6 fuentes de datos** (Spoonacular, Edamam, OpenFoodFacts, DB Local) con deduplicación automática y traducción inteligente por IA.

### 🎤 Parser de Voz con Dual AI
Registro por voz ultra-rápido usando **Groq (Llama 3.3 70B)** como motor primario y **Gemini 3.1 Flash** como backup de alta precisión.

---

## 🏗️ Arquitectura
Arquitectura por capas (Clean Architecture) con Service Locator y orquestación de datos centralizada.

| Capa | Tecnología |
| :--- | :--- |
| **UI** | Flutter 3.11 · Glassmorphism |
| **IA** | TFLite (YOLO26) · Groq (Llama 3.3) · Gemini 3.1 |
| **APIs** | Edamam · Spoonacular · OpenFoodFacts · USDA |
| **Gráficos** | fl_chart |

---

## 🚀 Instalación y Generación de APK

### Prerrequisitos
- Flutter SDK 3.11+
- Android Studio / VS Code

### 1. Configurar y Ejecutar
Copia el script de ejemplo y agrega tus keys:
```powershell
Copy-Item run.example.ps1 run.ps1
# Edita run.ps1 y ejecuta:
.\run.ps1
```

### 2. Generar APK (para descarga o Appetize)
Para que la app funcione correctamente en el APK, **debes incluir las API Keys** en el comando de build:

```bash
flutter build apk --release \
  --dart-define=GEMINI_API_KEY=tu_key \
  --dart-define=GROQ_API_KEY=tu_key \
  --dart-define=EDAMAM_APP_ID=tu_id \
  --dart-define=EDAMAM_APP_KEY=tu_key \
  --dart-define=USDA_API_KEY=tu_key \
  --dart-define=SPOONACULAR_API_KEY=tu_key
```

> **Ubicación del archivo**: Una vez termine, el APK estará en:
> `build/app/outputs/flutter-apk/app-release.apk`

### 🌐 Appetize.io
1. Sube el archivo `app-release.apk` a [Appetize.io](https://appetize.io/upload).
2. Te darán una URL para probar la app directamente en el navegador.

---

## 📄 Licencia
Distribuido bajo licencia **MIT**.

<p align="center">
  <strong>Construido con 💜 y mucho café ☕ en Chile 🇨🇱</strong><br>
  <sub>Francisco Paimilla · 2026</sub>
</p>
