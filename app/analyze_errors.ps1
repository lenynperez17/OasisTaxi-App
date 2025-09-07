Write-Host "======================================"
Write-Host "Ejecutando Flutter Analyze..."
Write-Host "======================================"

# Cambiar al directorio correcto
Set-Location "C:\Users\Lenyn\Documents\TODOS\NYNELs\NYNEL MKT\Proyectos\AppOasisTaxi\app"

# Ejecutar flutter analyze
flutter analyze | Out-File -FilePath flutter_analyze_results.txt -Encoding UTF8

# Leer resultados
$content = Get-Content flutter_analyze_results.txt -Raw

# Contar errores
$errors = ([regex]::Matches($content, "error •")).Count
$warnings = ([regex]::Matches($content, "warning •")).Count
$info = ([regex]::Matches($content, "info •")).Count

Write-Host ""
Write-Host "======================================"
Write-Host "RESUMEN DE ANALISIS:"
Write-Host "======================================"
Write-Host "Errores: $errors" -ForegroundColor Red
Write-Host "Warnings: $warnings" -ForegroundColor Yellow
Write-Host "Info: $info" -ForegroundColor Cyan
Write-Host "======================================"

if ($errors -gt 0) {
    Write-Host ""
    Write-Host "PRIMEROS ERRORES ENCONTRADOS:" -ForegroundColor Red
    Write-Host "======================================"
    $errorLines = $content -split "`n" | Where-Object { $_ -match "error •" } | Select-Object -First 30
    $errorLines | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "Resultados completos guardados en: flutter_analyze_results.txt" -ForegroundColor Green