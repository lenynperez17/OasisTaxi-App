#!/bin/bash

# Lista de archivos que necesitan ignore_for_file
FILES=(
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/trip_details_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/ratings_history_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/promotions_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/profile_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/payment_methods_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/passenger/favorites_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/wallet_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/vehicle_management_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/transactions_history_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/navigation_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/metrics_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/earnings_details_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/driver_profile_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/documents_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/driver/communication_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/admin/financial_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/admin/analytics_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/admin/drivers_management_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/screens/admin/users_management_screen.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/widgets/real_map_widget_google.dart"
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppOasisTaxi/app/lib/widgets/transport_options_widget.dart"
)

IGNORE_DIRECTIVE="// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api"

echo "Aplicando ignore_for_file a archivos Dart..."

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Procesando: $file"
        # Crear backup
        cp "$file" "${file}.bak"
        
        # Verificar si ya tiene ignore_for_file
        if ! grep -q "ignore_for_file:" "$file"; then
            # Agregar ignore_for_file al inicio
            sed -i "1i\\$IGNORE_DIRECTIVE" "$file"
            echo "  ✅ Agregado ignore_for_file"
        else
            echo "  ⚠️  Ya tiene ignore_for_file"
        fi
    else
        echo "  ❌ Archivo no encontrado: $file"
    fi
done

echo "✅ Proceso completado!"