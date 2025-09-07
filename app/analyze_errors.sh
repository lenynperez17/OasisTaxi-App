#!/bin/bash

echo "======================================"
echo "Ejecutando Flutter Analyze..."
echo "======================================"

# Ejecutar flutter analyze y guardar en archivo
flutter analyze > flutter_analyze_results.txt 2>&1

# Contar errores y warnings
ERRORS=$(grep -c "error •" flutter_analyze_results.txt 2>/dev/null || echo "0")
WARNINGS=$(grep -c "warning •" flutter_analyze_results.txt 2>/dev/null || echo "0")
INFO=$(grep -c "info •" flutter_analyze_results.txt 2>/dev/null || echo "0")

echo ""
echo "======================================"
echo "RESUMEN DE ANÁLISIS:"
echo "======================================"
echo "❌ Errores: $ERRORS"
echo "⚠️  Warnings: $WARNINGS"
echo "ℹ️  Info: $INFO"
echo "======================================"

# Mostrar los primeros 50 errores si existen
if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "PRIMEROS ERRORES ENCONTRADOS:"
    echo "======================================"
    grep "error •" flutter_analyze_results.txt | head -50
fi

echo ""
echo "Resultados completos guardados en: flutter_analyze_results.txt"