# Dockerfile para Flutter Web
FROM cirrusci/flutter:stable AS build

# Establecer directorio de trabajo
WORKDIR /workspace

# Copiar archivos de configuración
COPY pubspec.yaml pubspec.lock ./

# Instalar dependencias
RUN flutter pub get

# Copiar código fuente
COPY . .

# Compilar para web
RUN flutter build web --release

# Stage de producción con Nginx
FROM nginx:alpine

# Copiar build de Flutter a Nginx
COPY --from=build /workspace/build/web /usr/share/nginx/html

# Copiar configuración personalizada de Nginx
COPY ../docker/nginx.conf /etc/nginx/nginx.conf

# Exponer puerto 80
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]