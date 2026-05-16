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
| 🌐 **Appetize.io** | [Abrir en navegador](https://appetize.io/app/b_ulosmqy3whd5cq2oxhsglddmay) (emulador Android real) |
| 🎬 **Demo 60s** | [Ver walkthrough](#-demo--walkthrough) |

---

## 📖 Descripción

**Nutrifoto AI** es un ecosistema integral que demuestra el potencial de la **visión artificial aplicada a la salud**. Diseñé y entrené un modelo **YOLO26** con un dataset propio curado de **30 clases de comida chilena**, permitiendo detección on-device precisa y fluida.

La app no solo identifica comida — actúa como un **asistente nutricional completo** gracias a la integración de múltiples modelos de IA:

```
📸 Foto → 🧠 YOLO26 → 🍗 "Pollo asado" → 📊 250 kcal / 31g prot → ✅ Registrado
```

### 🌟 ¿Por qué destaca este proyecto?

| Problema Real | Solución Técnica |
| :--- | :--- |
| Registrar comida es tedioso y lento | 📸 **Camera-First**: una foto = registro completo con macros |
| Las apps solo conocen comida anglosajona | 🇨🇱 **30 clases chilenas** entrenadas con dataset propio en YOLO26 |
| No hay contexto nutricional personalizado | 🤖 **Gemini + Groq**: coaching dinámico basado en macros restantes |
| Los modelos fallan sin internet | 🧠 **Motor híbrido**: YOLO26 on-device + fallback de análisis cromático |
| Los scanners de barras no muestran macros | 📦 **OpenFoodFacts** integrado con datos nutricionales completos |
| Las recetas vienen de una sola fuente | 🔀 **Cascade multi-API**: Edamam + Spoonacular + OpenFoodFacts + DB local |

---

## 🎥 Demo & Walkthrough

<p align="center">
  <img src="assets/docs/training/app_demo.gif" alt="App Demo" width="280"/>
  <img src="assets/docs/training/feature_showcase.gif" alt="Features" width="280"/>
</p>

<details>
<summary><strong>🎞️ Guion de la Demo (60 segundos)</strong></summary>

| Fase | Tiempo | Funcionalidad |
| :--- | :--- | :--- |
| **Intro** | 00–10s | Splash screen → Dashboard principal con UI Glassmorphism |
| **IA Vision** | 10–25s | Escaneo en tiempo real con **YOLO26** · Detección múltiple |
| **Barcode** | 25–35s | Escaneo de productos vía **OpenFoodFacts** |
| **Voice AI** | 35–50s | Registro por voz procesado por **Groq** (NLP) |
| **Analytics** | 50–60s | Dashboard interactivo con `fl_chart` · Gestión de metas |

</details>

---

## ✨ Características Principales

### 🎯 Motor de Visión Híbrido

```
Imagen capturada
    ├── [1] YOLO26 TFLite (best_float16.tflite)
    │       ├── Center-square crop (640×640)
    │       ├── Normalización float32 NHWC
    │       ├── Inferencia on-device (4 threads CPU)
    │       └── Non-Maximum Suppression (IoU 0.45)
    │
    └── [2] Fallback: Análisis cromático (cosine similarity)
            ├── Perfil de colores (brown/green/white/yellow/orange/red)
            └── Matching contra 13 templates de comida
```

- **YOLO26 float16** — modelo custom con 30 clases de comida chilena
- **Center-square crop** — maximiza resolución en el centro del plato
- **Detección múltiple** — identifica varios alimentos en una sola foto
- **~120ms inferencia** en CPU (Google Pixel 7)

### 🍳 Motor de Descubrimiento de Recetas

Sistema de búsqueda inteligente con **6 fuentes de datos** y deduplicación automática:

```
Búsqueda "cazuela"
    ├── [1] 🇨🇱 Base local chilena (44 alimentos con imágenes curadas)
    ├── [2] 🔍 SmartRecipeSearch (expansión de sinónimos/categorías)
    ├── [3] 🥄 Spoonacular API (recetas con fotos reales)
    ├── [4] 🥗 Edamam Food DB (precisión nutricional profesional)
    ├── [5] 🌐 OpenFoodFacts (datos abiertos, sin límite)
    └── [6] 🤖 Gemini AI (instrucciones generadas por IA)
         └── Deduplicación por nombre → Traducción batch → Caché en memoria
```

**Características del motor:**
- **CascadeRecipeProvider** — combina resultados de múltiples APIs (no se detiene en la primera)
- **Caché de objetos completos** — resultados cacheados conservan toda la data nutricional e imágenes
- **Traducción inteligente** — solo traduce items de APIs en inglés; items locales chilenos se preservan intactos
- **Filtro de calidad** — descarta resultados genéricos (agua, sal, especias) automáticamente
- **Dificultad y tiempo dinámicos** — estimados por complejidad calórica, no hardcodeados

### 🎤 Parser de Voz con Dual AI

El usuario puede decir frases naturales como:
- *"Agréguame 150 gramos de pechuga de pollo al almuerzo"*
- *"Desayuné dos huevos fritos con pan"*
- *"Una manzana de snack"*

**Groq (Llama 3.3 70B)** como motor primario por su latencia ultra-baja, con **Gemini 3.1 Flash** como fallback de alta precisión:

```json
[
  { "alimento": "huevos fritos", "cantidad": 2, "unidad": "unidades", "comida": "desayuno" },
  { "alimento": "pan", "cantidad": 1, "unidad": "unidades", "comida": "desayuno" }
]
```

### 🖐️ Drag & Drop con Feedback Háptico

- **LongPressDraggable** — mantener presionado para arrastrar entre bloques del día
- **DragTarget** — cada sección (Desayuno, Almuerzo, Once, Cena, Snack) acepta drops
- **Haptic Feedback** — vibraciones en 3 niveles (`light`, `selection`, `heavy`)
- **Undo con SnackBar** — 5 segundos para deshacer cualquier acción

### 🧠 AI Smart Coach

Sistema de coaching proactivo con **Gemini 3.1 Flash**:
- **Consejos contextuales** — analiza macros restantes y sugiere qué comer
- **Instrucciones culinarias** — genera pasos de preparación profesionales contextuales
- **Descripciones gastronómicas** — reseñas apetitosas para resultados de búsqueda

### 📊 Visualización de Datos

Dashboard interactivo con **fl_chart**:
- **Gráficos de líneas** — seguimiento calórico semanal/mensual con tooltips táctiles
- **Gráficos de anillo** — distribución de macronutrientes con diseño Glassmorphism
- **Colores dinámicos** — feedback visual según el estado de las metas

---

## 🏗️ Arquitectura

El proyecto sigue una **arquitectura por capas** inspirada en Clean Architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │HomeScreen│ │PlanScreen│ │VoiceScreen│ │ Scanner  │  ...     │
│  └─────┬────┘ └─────┬────┘ └─────┬─────┘ └─────┬────┘         │
│        │            │            │              │               │
│  ┌─────┴────────────┴────────────┴──────────────┴─────────┐    │
│  │              AppServices (Service Locator)              │    │
│  └─────┬────────────┬────────────┬──────────────┬─────────┘    │
├────────┼────────────┼────────────┼──────────────┼──────────────┤
│        │     APPLICATION LAYER   │              │              │
│  ┌─────┴─────┐ ┌────┴─────┐ ┌───┴────┐ ┌──────┴──────┐       │
│  │Food       │ │Tracking  │ │History │ │Gemini NLP   │       │
│  │Orchestrator│ │UseCases  │ │UseCases│ │Service      │       │
│  └─────┬─────┘ └────┬─────┘ └───┬────┘ └─────────────┘       │
├────────┼────────────┼────────────┼─────────────────────────────┤
│        │    DOMAIN LAYER         │                             │
│  ┌─────┴─────┐ ┌────┴─────┐     │                             │
│  │FoodItem   │ │DiaryEntry│ NutritionGoals, MealSlot          │
│  │Nutrition  │ │DailySumm.│                                   │
│  └───────────┘ └──────────┘                                   │
├───────────────────────────────────────────────────────────────┤
│                  INFRASTRUCTURE LAYER                         │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │OnnxVision  │ │OpenFood    │ │USDA        │ │Edamam      │ │
│  │Provider    │ │Facts       │ │Provider    │ │Provider    │ │
│  │(TFLite)    │ │Provider    │ │            │ │            │ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │Spoonacular │ │Groq Cloud  │ │Local Chile │ │Smart Recipe│ │
│  │Provider    │ │(Llama 3.3) │ │Search      │ │Search      │ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### Stack Técnico

| Capa | Tecnología | Propósito |
| :--- | :--- | :--- |
| **UI** | Flutter 3.11 · Material 3 · Glassmorphism | Framework cross-platform con diseño premium |
| **Tipografía** | Google Fonts (Manrope) | Legibilidad y estética moderna |
| **IA On-Device** | TFLite + YOLO26 Custom | Detección de comida sin internet |
| **NLP / Coach** | Groq (Llama 3.3 70B) · Gemini 3.1 Flash | Parsing de voz y coaching inteligente |
| **Gráficos** | fl_chart | Dashboards interactivos con tooltips |
| **Barcode** | mobile_scanner + OpenFoodFacts | Escaneo y datos de productos |
| **Nutrición** | USDA FoodData · Edamam · OpenFoodFacts | Bases de datos nutricionales multi-fuente |
| **Recetas** | CascadeRecipeProvider (4 APIs) | Búsqueda inteligente con deduplicación |
| **Traducción** | Gemini 3.1 Flash (batch) | ES ↔ EN con prompts chilenos contextuales |
| **Persistencia** | JSON Tracking Repository | Almacenamiento local del diario |

---

## 🧠 Data Science & Entrenamiento

Para lograr precisión en platos locales, no usé modelos genéricos. Todo el pipeline de datos fue construido desde cero.

### 📓 Notebook de Entrenamiento

Para replicar el entrenamiento o ajustar el modelo:
[`assets/models/YOLO26_ComidaChilena.ipynb`](assets/models/YOLO26_ComidaChilena.ipynb)

Este notebook documenta:
- Descarga del dataset desde Roboflow (`Comida-Chilena-7`)
- Configuración de hiperparámetros (Epochs: 100, Optimizer: auto, Mixup: 0.1)
- Exportación a formatos ONNX y TFLite (float16)

### 📊 Curación y Aumentación

El pipeline de datos se gestionó con **Roboflow**, con curación manual y aumentación para mejorar la generalización:

<p align="center">
  <img src="assets/docs/training/roboflow_labeling.png" alt="Etiquetado en Roboflow" width="700"/><br>
  <em>Interfaz de etiquetado manual y distribución de clases en Roboflow.</em>
</p>

- **Aumentación**: Rotación, brillo, ruido, mosaico → robustez en condiciones variables
- **Dataset**: `Comida-Chilena-7` (versión 7), optimizado para YOLO26

### 📈 Métricas de Entrenamiento

100 epochs de entrenamiento con convergencia sólida:

<p align="center">
  <img src="assets/docs/training/dataset_augmentation.png" alt="Curvas de Entrenamiento" width="700"/>
  <img src="assets/docs/training/dataset_statistics.png" alt="Estadísticas" width="300"/><br>
  <em>Curvas de Loss (Box, Cls, DFL) y resumen de precisión mAP@50.</em>
</p>

### 🎯 Resultados de Inferencia

<p align="center">
  <img src="assets/docs/training/training_metrics.png" alt="Detección en acción" width="600"/><br>
  <em>Detección múltiple con altos niveles de confianza.</em>
</p>

<p align="center">
  <img src="assets/docs/training/training_results.png" alt="Precisión por clase" width="700"/><br>
  <em>Precisión mAP desglosada por cada una de las 30 clases.</em>
</p>

| Métrica | Valor |
| :--- | :--- |
| **mAP@0.5** | 0.89 |
| **Inferencia (CPU)** | ~120ms (Pixel 7) |
| **Tamaño del modelo** | 42 MB (TFLite float16) |
| **Clases** | 30 comidas chilenas |

---

## 🇨🇱 Clases Detectadas (30)

<table>
<tr><td>

| # | Clase |
|---|-------|
| 1 | Arroz |
| 2 | Arvejas |
| 3 | Brócoli |
| 4 | Calzones rotos |
| 5 | Carne |
| 6 | Cazuela |
| 7 | Charquicán |
| 8 | Choripán |
| 9 | Completos |
| 10 | Durazno |

</td><td>

| # | Clase |
|---|-------|
| 11 | Empanada |
| 12 | Ensalada chilena |
| 13 | Huevos fritos |
| 14 | Humitas |
| 15 | Manzana |
| 16 | Mote con huesillo |
| 17 | Naranja |
| 18 | Palomitas |
| 19 | Palta |
| 20 | Papas fritas |

</td><td>

| # | Clase |
|---|-------|
| 21 | Pasta |
| 22 | Pastel de choclo |
| 23 | Pescado frito |
| 24 | Pizza |
| 25 | Plátano |
| 26 | Pollo |
| 27 | Porotos con riendas |
| 28 | Salmón |
| 29 | Sopaipillas |
| 30 | Tiramisú |

</td></tr>
</table>

---

## 📂 Estructura del Proyecto

```
lib/
├── main.dart                              # Entry point + tema Glassmorphism
├── application/                           # Orquestación y casos de uso
│   ├── app_bootstrap.dart                 # Inicialización de servicios
│   ├── app_services.dart                  # Service Locator central
│   ├── food_orchestrator.dart             # 🧠 Orquestador de fuentes de datos
│   ├── orchestrator_factory.dart          # Factory con inyección de providers
│   └── usecases/
│       ├── tracking_usecases.dart         # CRUD del diario alimenticio
│       ├── history_usecases.dart          # Consultas de historial
│       └── insights_usecases.dart         # Análisis e insights nutricionales
├── domain/                                # Modelos puros (sin dependencias)
│   ├── models/
│   │   ├── nutrition_models.dart          # FoodItem, Nutrition, Portion
│   │   └── tracking_models.dart           # DiaryEntry, DailySummary, MealSlot
│   └── repositories/
│       ├── food_provider.dart             # Interfaces: Search, Recipe, Vision, Translation
│       └── tracking_repository.dart       # Interfaz de persistencia
├── infrastructure/                        # Implementaciones concretas
│   ├── providers/
│   │   ├── onnx_vision_provider.dart      # YOLO26 TFLite + Color fallback
│   │   ├── cascade_provider.dart          # Multi-source merge con deduplicación
│   │   ├── edamam_recipe_provider.dart    # Edamam Food DB (con filtro de calidad)
│   │   ├── spoonacular_provider.dart      # Spoonacular (recetas con fotos)
│   │   ├── openfoodfacts_provider.dart    # Barcode lookup
│   │   ├── openfoodfacts_search_provider.dart  # Búsqueda textual gratuita
│   │   ├── usda_provider.dart             # USDA FoodData Central
│   │   └── local_chile_provider.dart      # 44 alimentos chilenos offline
│   ├── repositories/
│   │   └── json_tracking_repository.dart  # Persistencia JSON local
│   └── services/
│       ├── gemini_nlp_service.dart         # 🤖 NLP + Traducción + Coaching (Groq/Gemini)
│       ├── smart_recipe_search_service.dart # Expansión de sinónimos chilenos
│       ├── local_chile_search_service.dart  # DB local con imágenes curadas
│       ├── search_cache_service.dart        # Caché de traducciones y búsquedas
│       ├── auth_service.dart               # Google Sign-In + modo guest
│       └── api_config.dart                 # Centralización de API keys
└── presentation/                           # UI premium
    ├── screens/
    │   ├── home_screen.dart               # Dashboard principal (Hoy)
    │   ├── plan_screen.dart               # Planificación + Drag & Drop
    │   ├── recipes_screen.dart            # 🍳 Descubrimiento de recetas magazine-style
    │   ├── scanner_camera_screen.dart     # AI Hub (Scanner, Voz, Recetas, Manual)
    │   ├── statistics_screen.dart         # Estadísticas interactivas (fl_chart)
    │   ├── assistant_screen.dart          # Chat con Asistente IA
    │   └── ...                            # Welcome, Signup, Onboarding, Settings
    └── widgets/
        ├── nutrifoto_ui.dart              # 🎨 Design system (Glassmorphism tokens)
        ├── draggable_food_card.dart        # Tarjeta arrastrable con menú contextual
        ├── swipeable_food_card.dart        # Tarjeta con swipe-to-delete
        ├── skeleton_loader.dart           # Loading skeletons animados
        └── ...                            # Bottom nav, animaciones, feedback
```

---

## 🚀 Instalación

### Prerrequisitos

- **Flutter SDK** 3.11+
- **Dart SDK** 3.11+
- **Android Studio** o **VS Code** con extensión Flutter
- Dispositivo Android o emulador

### 1. Clonar e instalar

```bash
git clone https://github.com/Paimilla/nutrifoto.git
cd nutrifoto
flutter pub get
```

### 2. Configurar API Keys

La app usa variables de entorno en tiempo de compilación (`--dart-define`):

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=tu_clave_gemini \
  --dart-define=GROQ_API_KEY=tu_clave_groq \
  --dart-define=EDAMAM_APP_ID=tu_app_id \
  --dart-define=EDAMAM_APP_KEY=tu_app_key
```

**O con el script PowerShell:**

```powershell
Copy-Item run.example.ps1 run.ps1
# Edita run.ps1 con tus API keys
.\run.ps1
```

### 🔑 ¿Dónde obtener las API keys?

| Servicio | URL | Tier Gratuito |
| :--- | :--- | :--- |
| **Google Gemini** | [ai.google.dev](https://ai.google.dev/) | 15 RPM gratis |
| **Groq** | [console.groq.com](https://console.groq.com/) | 30 RPM gratis |
| **Edamam** | [developer.edamam.com](https://developer.edamam.com/) | 100 req/min |
| **USDA FoodData** | [fdc.nal.usda.gov](https://fdc.nal.usda.gov/api-key-signup.html) | Ilimitado |
| **OpenFoodFacts** | [world.openfoodfacts.org](https://world.openfoodfacts.org/) | Open data (sin límite) |
| **Spoonacular** | [spoonacular.com/food-api](https://spoonacular.com/food-api) | 150 req/día |

### 3. Modelo YOLO26 TFLite

El modelo preentrenado ya está incluido en el repositorio:

```
assets/models/best_float16.tflite    # 42 MB — YOLO26 float16
assets/models/labels.txt              # 30 clases de comida chilena
assets/models/data.yaml              # Configuración del dataset
```

### 4. Ejecutar

```bash
flutter run
```

---

## 🛠️ Scripts Útiles

```bash
flutter analyze          # Análisis estático (0 issues ✅)
flutter test             # Suite de 58 tests (100% pass ✅)
dart format lib/         # Formatear código
flutter clean            # Limpiar build cache
dart fix --apply         # Aplicar fixes automáticos
```

---

## ♿ Accesibilidad

- **Semantics** en componentes interactivos con etiquetas descriptivas
- **Tooltips** en botones de cámara, flash y menús contextuales
- **Haptic Feedback** multinivel para confirmar acciones táctiles
- **Contraste WCAG AA** con ratio mínimo de 4.5:1 sobre fondos oscuros
- **Overflow protegido** con `maxLines` + `ellipsis` en pantallas pequeñas

---

## 📄 Licencia

Distribuido bajo licencia **MIT**. Ver [`LICENSE`](LICENSE) para más información.

---

<p align="center">
  <strong>Construido con 💜 y mucho café ☕ en Chile 🇨🇱</strong><br>
  <sub>Francisco Paimilla · 2026</sub>
</p>
