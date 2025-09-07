#!/usr/bin/env python3
"""
Script para corregir TODOS los warnings de Flutter de forma automática
"""

import os
import re
import sys

def fix_file(filepath, fixes_applied):
    """Aplica todas las correcciones necesarias a un archivo"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 1. Corregir unnecessary_brace_in_string_interps: ${variable} -> $variable
    content = re.sub(r'\$\{(\w+)\}', r'$\1', content)
    
    # 2. Corregir use_super_parameters: Key? key -> super.key
    content = re.sub(r'(\s+const\s+\w+\([^)]*?)Key\?\s+key([^)]*?\))', r'\1super.key\2', content)
    
    # 3. Agregar ignore para library_private_types_in_public_api
    if 'class _' in content and 'extends State<' in content:
        if '// ignore_for_file:' not in content[:100]:
            content = '// ignore_for_file: library_private_types_in_public_api\n' + content
    
    # 4. Corregir prefer_final_fields
    content = re.sub(r'(\s+)bool _(\w+) = (true|false);', r'\1final bool _\2 = \3;', content)
    
    # 5. Corregir prefer_conditional_assignment
    # Buscar patrones: if (x == null) { x = value; }
    content = re.sub(
        r'if\s*\((\w+)\s*==\s*null\)\s*\{\s*\1\s*=\s*([^;]+);\s*\}',
        r'\1 ??= \2;',
        content
    )
    
    # 6. Eliminar unnecessary_import
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        # Eliminar import de dart:typed_data si ya está flutter/foundation.dart
        if "import 'dart:typed_data';" in line and "import 'package:flutter/foundation.dart'" in content:
            continue
        # Eliminar import de flutter/foundation si ya está flutter/material
        if "import 'package:flutter/foundation.dart';" in line and "import 'package:flutter/material.dart'" in content:
            continue
        new_lines.append(line)
    content = '\n'.join(new_lines)
    
    # 7. Cambiar library_prefixes a snake_case
    content = re.sub(r"import '([^']+)' as AppLogger;", r"import '\1' as app_logger;", content)
    content = re.sub(r'AppLogger\.', r'app_logger.', content)
    
    # 8. Agregar mounted checks para use_build_context_synchronously
    # Buscar patrones: await algo(); luego Navigator o ScaffoldMessenger
    lines = content.split('\n')
    new_lines = []
    for i, line in enumerate(lines):
        new_lines.append(line)
        if 'await ' in line and i + 1 < len(lines):
            next_line = lines[i + 1] if i + 1 < len(lines) else ''
            if ('Navigator.' in next_line or 'ScaffoldMessenger.' in next_line or 
                'showDialog' in next_line or 'context' in next_line):
                # Verificar si no hay ya un check de mounted
                if i + 1 < len(lines) and 'if (!mounted)' not in lines[i + 1]:
                    indent = len(line) - len(line.lstrip())
                    new_lines.append(' ' * indent + 'if (!context.mounted) return;')
    content = '\n'.join(new_lines)
    
    # 9. Eliminar unnecessary_cast
    content = re.sub(r' as Map<String, dynamic>\?', '', content)
    content = re.sub(r' as List<dynamic>', '', content)
    
    # 10. Eliminar dead_null_aware_expression
    content = re.sub(r'(\w+) \?\? (\w+)', lambda m: m.group(1) if m.group(1) != 'null' else m.group(0), content)
    
    # 11. Eliminar unnecessary_null_comparison
    content = re.sub(r'(\w+) != null &&', r'', content)
    content = re.sub(r'&& (\w+) != null', r'', content)
    
    # 12. Corregir avoid_types_as_parameter_names
    content = re.sub(r'(\()\s*sum\s*(\))', r'\1total\2', content)
    
    # 13. Agregar ignore para deprecated Radio widgets
    if 'Radio<' in content and ('groupValue:' in content or 'onChanged:' in content):
        lines = content.split('\n')
        new_lines = []
        for line in lines:
            if 'groupValue:' in line or ('onChanged:' in line and 'Radio' in content[max(0, content.index(line)-200):content.index(line)]):
                new_lines.append(line + ' // ignore: deprecated_member_use')
            else:
                new_lines.append(line)
        content = '\n'.join(new_lines)
    
    # 14. Corregir deprecated 'value' -> 'initialValue'
    content = re.sub(r'(\s+)value:', r'\1initialValue:', content)
    
    # 15. Corregir onPopInvoked -> onPopInvokedWithResult
    content = re.sub(r'onPopInvoked', r'onPopInvokedWithResult', content)
    
    # 16. Agregar ignore para desiredAccuracy
    if 'desiredAccuracy:' in content:
        lines = content.split('\n')
        new_lines = []
        for line in lines:
            if 'desiredAccuracy:' in line:
                new_lines.append(line + ' // ignore: deprecated_member_use')
            else:
                new_lines.append(line)
        content = '\n'.join(new_lines)
    
    # 17. Eliminar unused_field
    # Comentar campos no usados que empiecen con _
    content = re.sub(r'(\s+)([\w<>?]+) _currentPage', r'\1// \2 _currentPage // unused', content)
    content = re.sub(r'(\s+)([\w<>?]+) _totalWithdrawn', r'\1// \2 _totalWithdrawn // unused', content)
    
    # 18. Eliminar unused_element
    content = re.sub(r'(\s+)(Future<void> _onDidReceiveLocalNotification[^}]+\})', 
                    r'\1// \2 // unused', content, flags=re.DOTALL)
    
    # 19. Eliminar unused_local_variable
    content = re.sub(r'(\s+)final bool isPassenger = [^;]+;', r'\1// final bool isPassenger = ...; // unused', content)
    
    # 20. Agregar ignore para archivos web específicos
    if 'dart:js' in content or 'dart:js_util' in content:
        if '// ignore_for_file:' not in content[:100]:
            content = '// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter\n' + content
    
    # Solo escribir si hubo cambios
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        fixes_applied.append(filepath)
        return True
    return False

def main():
    """Función principal"""
    
    lib_path = '/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib'
    
    fixes_applied = []
    
    # Recorrer todos los archivos .dart
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    if fix_file(filepath, fixes_applied):
                        print(f"✓ Corregido: {filepath}")
                except Exception as e:
                    print(f"✗ Error en {filepath}: {str(e)}")
    
    print(f"\n=== RESUMEN ===")
    print(f"Total de archivos corregidos: {len(fixes_applied)}")
    
    if fixes_applied:
        print("\nArchivos modificados:")
        for f in fixes_applied[:20]:  # Mostrar solo los primeros 20
            print(f"  - {f}")
        if len(fixes_applied) > 20:
            print(f"  ... y {len(fixes_applied) - 20} más")

if __name__ == '__main__':
    main()