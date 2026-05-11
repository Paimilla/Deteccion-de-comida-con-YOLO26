# ═══════════════════════════════════════════════════════════════════════════════
# 🧹 NUTRIFOTO — Script de Limpieza y Auditoría de Deuda Técnica
# ═══════════════════════════════════════════════════════════════════════════════
# Ejecutar desde la raíz del proyecto Flutter:
#   powershell -ExecutionPolicy Bypass -File scripts/cleanup.ps1
# ═══════════════════════════════════════════════════════════════════════════════

$projectRoot = Split-Path -Parent $PSScriptRoot
$libDir = Join-Path $projectRoot "lib"
$assetsDir = Join-Path $projectRoot "assets"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🧹 Nutrifoto — Auditoría de Deuda Técnica" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Archivos temporales o residuales (.fixed, .bak, .old) ────────────────
Write-Host "📁 [1/6] Buscando archivos residuales (.fixed, .bak, .old)..." -ForegroundColor Yellow
$residualFiles = Get-ChildItem -Path $projectRoot -Recurse -File |
    Where-Object { $_.Extension -match '\.(fixed|bak|old|tmp)$' -or $_.Name -match '\.dart\.' }
if ($residualFiles) {
    Write-Host "   ⚠️  Encontrados $($residualFiles.Count) archivo(s) residual(es):" -ForegroundColor Red
    foreach ($f in $residualFiles) {
        $rel = $f.FullName.Replace($projectRoot, "").TrimStart("\")
        Write-Host "      - $rel ($([math]::Round($f.Length / 1024, 1)) KB)" -ForegroundColor Gray
    }
    Write-Host "   💡 Elimina con: Remove-Item <ruta>" -ForegroundColor DarkYellow
} else {
    Write-Host "   ✅ Sin archivos residuales" -ForegroundColor Green
}

# ─── 2. Documentación .md obsoleta en raíz del proyecto ──────────────────────
Write-Host ""
Write-Host "📄 [2/6] Documentación .md en raíz (candidata a consolidar)..." -ForegroundColor Yellow
$mdFiles = Get-ChildItem -Path $projectRoot -File -Filter "*.md" |
    Where-Object { $_.Name -ne "README.md" }
if ($mdFiles) {
    Write-Host "   ⚠️  $($mdFiles.Count) archivo(s) .md (podrían consolidarse):" -ForegroundColor Red
    foreach ($f in $mdFiles) {
        Write-Host "      - $($f.Name) ($([math]::Round($f.Length / 1024, 1)) KB)" -ForegroundColor Gray
    }
    Write-Host "   💡 Mueve a docs/ o elimina tras consolidar en README.md" -ForegroundColor DarkYellow
} else {
    Write-Host "   ✅ Solo README.md presente" -ForegroundColor Green
}

# ─── 3. Scripts Python huérfanos ─────────────────────────────────────────────
Write-Host ""
Write-Host "🐍 [3/6] Buscando scripts Python huérfanos en raíz..." -ForegroundColor Yellow
$pyFiles = Get-ChildItem -Path $projectRoot -File -Filter "*.py"
if ($pyFiles) {
    Write-Host "   ⚠️  $($pyFiles.Count) script(s) Python en raíz:" -ForegroundColor Red
    foreach ($f in $pyFiles) {
        Write-Host "      - $($f.Name)" -ForegroundColor Gray
    }
    Write-Host "   💡 Mueve a scripts/ o elimina si ya no se usan" -ForegroundColor DarkYellow
} else {
    Write-Host "   ✅ Sin scripts Python sueltos" -ForegroundColor Green
}

# ─── 4. Assets declarados pero inexistentes en pubspec.yaml ──────────────────
Write-Host ""
Write-Host "📦 [4/6] Verificando assets declarados en pubspec.yaml..." -ForegroundColor Yellow
$pubspec = Get-Content (Join-Path $projectRoot "pubspec.yaml") -Raw
$assetLines = $pubspec | Select-String -Pattern "^\s+- (assets/.+)" -AllMatches
$missingAssets = @()
foreach ($match in $assetLines.Matches) {
    $assetPath = $match.Groups[1].Value.Trim()
    $fullPath = Join-Path $projectRoot $assetPath
    if (-not (Test-Path $fullPath)) {
        $missingAssets += $assetPath
    }
}
if ($missingAssets) {
    Write-Host "   ⚠️  $($missingAssets.Count) asset(s) declarados pero NO existen:" -ForegroundColor Red
    foreach ($a in $missingAssets) {
        Write-Host "      - $a" -ForegroundColor Gray
    }
    Write-Host "   💡 Elimina la línea del pubspec o crea el archivo" -ForegroundColor DarkYellow
} else {
    Write-Host "   ✅ Todos los assets declarados existen" -ForegroundColor Green
}

# ─── 5. Archivos .dart con código muerto (sin ser importados) ────────────────
Write-Host ""
Write-Host "🔍 [5/6] Buscando archivos .dart potencialmente huérfanos..." -ForegroundColor Yellow
$dartFiles = Get-ChildItem -Path $libDir -Recurse -File -Filter "*.dart"
$orphans = @()
foreach ($df in $dartFiles) {
    if ($df.Name -eq "main.dart") { continue }
    $basename = $df.Name
    # Buscar si algún otro archivo .dart importa este basename
    $importPattern = "import.*['/]$basename"
    $found = Get-ChildItem -Path $libDir -Recurse -File -Filter "*.dart" |
        Where-Object { $_.FullName -ne $df.FullName } |
        Get-Content -ErrorAction SilentlyContinue |
        Select-String -Pattern $importPattern -Quiet
    if (-not $found) {
        $rel = $df.FullName.Replace($projectRoot, "").TrimStart("\")
        $orphans += $rel
    }
}
if ($orphans) {
    Write-Host "   ⚠️  $($orphans.Count) archivo(s) sin import encontrado:" -ForegroundColor Red
    foreach ($o in $orphans) {
        Write-Host "      - $o" -ForegroundColor Gray
    }
    Write-Host "   💡 Verifica manualmente antes de eliminar (pueden ser entry points)" -ForegroundColor DarkYellow
} else {
    Write-Host "   ✅ Todos los archivos .dart están referenciados" -ForegroundColor Green
}

# ─── 6. Ejecutar flutter analyze ─────────────────────────────────────────────
Write-Host ""
Write-Host "🔬 [6/6] Ejecutando flutter analyze..." -ForegroundColor Yellow
Push-Location $projectRoot
try {
    $analyzeOutput = flutter analyze 2>&1 | Out-String
    $issueCount = ($analyzeOutput | Select-String -Pattern "(\d+) issue" -AllMatches).Matches
    if ($issueCount) {
        Write-Host "   ⚠️  $($issueCount[0].Groups[1].Value) issue(s) detectados por flutter analyze" -ForegroundColor Red
        Write-Host "   💡 Ejecuta 'flutter analyze' para ver detalles" -ForegroundColor DarkYellow
    } else {
        Write-Host "   ✅ flutter analyze: sin issues" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  No se pudo ejecutar flutter analyze: $_" -ForegroundColor Red
} finally {
    Pop-Location
}

# ─── Resumen ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " ✨ Auditoría completada" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Comandos útiles de limpieza:" -ForegroundColor White
Write-Host "  flutter clean                    # Limpia build cache" -ForegroundColor Gray
Write-Host "  flutter pub get                  # Reinstala dependencias" -ForegroundColor Gray
Write-Host "  dart fix --apply                 # Aplica fixes automáticos" -ForegroundColor Gray
Write-Host "  dart format lib/                 # Formatea todo el código" -ForegroundColor Gray
Write-Host ""
