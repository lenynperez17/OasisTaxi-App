#!/usr/bin/env python3
"""
Script para verificar imports no utilizados en archivos Dart
Busca patrones comunes de código no utilizado que podrían generar advertencias
"""
import os
import re
import glob

def check_dart_import_usage(file_path):
    """Verifica si los imports dart: están siendo utilizados en el archivo"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []

    # Verificar dart:convert
    if "import 'dart:convert'" in content:
        if not any(pattern in content for pattern in ['jsonEncode', 'jsonDecode', 'convert', 'utf8', 'base64', 'json.']):
            issues.append("dart:convert importado pero no usado")

    # Verificar dart:io
    if "import 'dart:io'" in content:
        if not any(pattern in content for pattern in ['Platform', 'File(', 'Directory(', 'HttpClient', 'Process.', 'stdin', 'stdout', 'stderr']):
            issues.append("dart:io importado pero no usado")

    # Verificar dart:async
    if "import 'dart:async'" in content:
        if not any(pattern in content for pattern in ['Timer', 'Completer', 'StreamController', 'StreamSubscription', 'Future.', 'Stream.']):
            issues.append("dart:async importado pero no usado")

    # Verificar dart:math
    if "import 'dart:math'" in content:
        if not any(pattern in content for pattern in ['math.', 'Random', 'sqrt', 'sin', 'cos', 'tan', 'pi', 'e', 'max', 'min']):
            issues.append("dart:math importado pero no usado")

    # Verificar dart:typed_data
    if "import 'dart:typed_data'" in content:
        if not any(pattern in content for pattern in ['Uint8List', 'Int32List', 'Float64List', 'ByteData']):
            issues.append("dart:typed_data importado pero no usado")

    # Verificar dart:ui
    if "import 'dart:ui'" in content:
        if not any(pattern in content for pattern in ['ui.', 'Color(', 'Offset(', 'Size(', 'Rect.']):
            issues.append("dart:ui importado pero no usado")

    return issues

def check_unused_variables(file_path):
    """Busca variables declaradas pero no utilizadas"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []

    # Buscar variables con final/var/const que podrían no estar siendo usadas
    var_pattern = r'^\s*(final|var|const)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*='
    matches = re.finditer(var_pattern, content, re.MULTILINE)

    for match in matches:
        var_name = match.group(2)
        # Buscar si la variable se usa después de la declaración
        after_declaration = content[match.end():]
        if var_name not in after_declaration:
            issues.append(f"Variable '{var_name}' declarada pero no usada")

    return issues

def main():
    """Función principal para verificar todo el proyecto"""
    lib_path = "lib"

    print("🔍 VERIFICACIÓN EXHAUSTIVA DE CÓDIGO NO UTILIZADO")
    print("=" * 60)

    # Obtener todos los archivos .dart
    dart_files = glob.glob(os.path.join(lib_path, "**/*.dart"), recursive=True)

    total_issues = 0

    for file_path in sorted(dart_files):
        rel_path = os.path.relpath(file_path)

        # Verificar imports dart:
        import_issues = check_dart_import_usage(file_path)

        # Verificar variables no usadas
        var_issues = check_unused_variables(file_path)

        all_issues = import_issues + var_issues

        if all_issues:
            print(f"\n📁 {rel_path}")
            for issue in all_issues:
                print(f"   ⚠️  {issue}")
                total_issues += 1

    print(f"\n{'='*60}")
    print(f"📊 RESUMEN: {total_issues} problemas encontrados")

    if total_issues == 0:
        print("✅ ¡No se encontraron problemas de código no utilizado!")
    else:
        print("❌ Se encontraron problemas que pueden generar advertencias")

if __name__ == "__main__":
    main()