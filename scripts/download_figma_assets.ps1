# ============================================================
# download_figma_assets.ps1
# Descarga todos los assets del landing desde el servidor
# del plugin Figma (localhost:3845) hacia assets/images/.
#
# REQUISITO: Figma Desktop debe estar abierto con el plugin
#            activo (el servidor se levanta automáticamente).
#
# USO:
#   1. Abre Figma Desktop con el archivo del proyecto
#   2. Ejecuta:  .\scripts\download_figma_assets.ps1
#   3. Luego:    flutter run -d chrome
# ============================================================

$ErrorActionPreference = "Stop"

$base = "http://localhost:3845/assets"
$projectRoot = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $projectRoot "assets\images"

Write-Host "`n=== Verificando servidor Figma en localhost:3845 ===" -ForegroundColor Cyan

try {
    $test = Invoke-WebRequest -Uri "$base/b47030533d3ca252deaf6eb69b5072a1539bd7bf.png" `
                              -Method Head -TimeoutSec 3 -UseBasicParsing
    Write-Host "Servidor accesible (HTTP $($test.StatusCode))." -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se puede conectar a localhost:3845." -ForegroundColor Red
    Write-Host "  Asegurate de que Figma Desktop este abierto con el plugin activo.`n" -ForegroundColor Yellow
    exit 1
}

# ── Mapa hash → nombre local ───────────────────────────────────────────────
$assets = [ordered]@{
    # Banners carousel
    "banner_astro.png"            = "b47030533d3ca252deaf6eb69b5072a1539bd7bf.png"
    "banner_baloto.png"           = "cbd40f41c19a8464511ff2fd521bdd86b95fffca.png"
    "banner_3.png"                = "4fde00970fda1344464ab5def65f608cbf222a42.png"
    "banner_4.png"                = "c0da601f34c1da52afdf5e26a2f703c66e304d5a.png"

    # Logos acumulados
    "logo_doble_chance.png"       = "f8e29c32297f408243d120501ada36b050d453e3.png"
    "logo_baloto_revancha.png"    = "1c7baf2a3aff993d3db22c38813ad0258b377c6f.png"
    "logo_chance_millonario.png"  = "ea064b832bca611242a868dab7df361301ca3e82.png"
    "logo_mi_loto.png"            = "e9a67e5a9d6e7a4117d754ea288bbdfaaa087a95.png"
    "logo_i_color_loto.png"       = "2d81a9213b94ac0bff85da3dc66cb6330988e8c2.png"

    # Logos resultados
    "logo_risaralda.png"          = "c2aa3b102c05ed4ab83400641a537b3d6be19678.png"
    "logo_valle.png"              = "225ac0529f994202a7ed3e642e963b2db2700a6b.png"

    # Icono seccion resultados (SVG)
    "icon_resultados.svg"         = "575e12a861be1fb5a35f1cb83ba97efd90b1cd58.svg"

    # Imagenes juegos
    "juego_1.png"                 = "a9cc39b706a1dd145fc51ad3aff2246f73c38a82.png"
    "juego_2.png"                 = "aa454a3c5e9b223e24249af9fb1c6cb026a1c311.png"
    "juego_3.png"                 = "21c7ec19b96f07dd8a250fded63cf35ecf7a7cc0.png"
    "juego_4.png"                 = "1c6e439eead3e7b8e8d623836560e6aa3fcd609e.png"
    "juego_5.png"                 = "1a1c1889dc202ac1375bfdc976b45f0d70b09c04.png"
    "juego_6.png"                 = "b5bd2599ad9cc09f71acac5389e158dffe5ca304.png"
    "juego_7.png"                 = "7c86b9533bfa6aa7959ab359f1ac497d7fa12adc.png"
    "juego_8.png"                 = "1bb18146dd96d749a611e4587c9c267f5b56ba2f.png"
    "juego_9.png"                 = "0bfdad8d23ae832ad75071127772ea484051e050.png"
    "juego_10.png"                = "b8aab955976b23412fa73b4e06c81243f618d6c7.png"

    # Footer logos regulatorios
    "logo_vigilado.png"           = "2cb7a2d631676018eb58f2dd2263c5b442c07e62.png"
    "logo_coljuegos.png"          = "8b8a69169e9302728a46b810ae20515727620835.png"
}

Write-Host "`n=== Descargando $($assets.Count) assets hacia: $dest ===`n" -ForegroundColor Cyan

$ok = 0
$fail = 0

foreach ($name in $assets.Keys) {
    $hash   = $assets[$name]
    $url    = "$base/$hash"
    $output = Join-Path $dest $name

    try {
        Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing -TimeoutSec 10
        Write-Host "  [OK] $name" -ForegroundColor Green
        $ok++
    } catch {
        Write-Host "  [FAIL] $name  ($($_.Exception.Message))" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Completado: $ok/$($assets.Count) assets descargados correctamente." -ForegroundColor Green
    Write-Host "Ejecuta 'flutter run -d chrome' para ver las imagenes.`n" -ForegroundColor Cyan
} else {
    Write-Host "Parcial: $ok OK, $fail fallaron." -ForegroundColor Yellow
    Write-Host "Revisa que Figma siga abierto y vuelve a intentarlo.`n"
}
