# ══════════════════════════════════════════════════════════════════════
# Nutrifoto AI — Script de ejecución con variables de entorno
# ══════════════════════════════════════════════════════════════════════
# 1. Copia este archivo: Copy-Item run.example.ps1 run.ps1
# 2. Reemplaza las claves con tus propias API keys
# 3. Ejecuta: .\run.ps1
# ══════════════════════════════════════════════════════════════════════

flutter run `
  --dart-define=GEMINI_API_KEY=TU_CLAVE_GEMINI_AQUI `
  --dart-define=EDAMAM_APP_ID=TU_APP_ID_AQUI `
  --dart-define=EDAMAM_APP_KEY=TU_APP_KEY_AQUI `
  --dart-define=REGISTRATION_WEBHOOK_URL=TU_WEBHOOK_URL_AQUI
