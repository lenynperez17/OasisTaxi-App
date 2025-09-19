# 🚖 OASIS TAXI PERÚ - Dockerfile para CI/CD
# Imagen optimizada para builds Flutter con Android SDK y herramientas

# Usar imagen base Ubuntu optimizada para Flutter
FROM ubuntu:22.04

# Información del maintainer
LABEL maintainer="OasisTaxi Peru Dev Team"
LABEL description="Flutter build environment para OasisTaxi con Android SDK"
LABEL version="1.0.0"

# Variables de entorno
ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_VERSION=3.24.4
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV NODE_VERSION=18
ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# Crear usuario no-root para builds
RUN groupadd -r flutter && useradd -r -g flutter flutter

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    # Herramientas básicas
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    # Java Development Kit
    openjdk-11-jdk \
    # Herramientas de build
    build-essential \
    pkg-config \
    # Limpieza de cache
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar Android SDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd ${ANDROID_HOME}/cmdline-tools && \
    curl -o sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip sdk-tools.zip && \
    rm sdk-tools.zip && \
    mv cmdline-tools latest

# Configurar Android SDK
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-33" \
    "platforms;android-34" \
    "build-tools;33.0.0" \
    "build-tools;34.0.0" \
    "cmdline-tools;latest"

# Instalar Flutter SDK
RUN cd /opt && \
    curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    tar xf flutter.tar.xz && \
    rm flutter.tar.xz && \
    chown -R flutter:flutter ${FLUTTER_HOME}

# Instalar Node.js para Cloud Functions
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs

# Configurar Flutter
RUN flutter config --android-sdk ${ANDROID_HOME} && \
    flutter config --no-analytics && \
    flutter doctor --android-licenses && \
    flutter precache

# Instalar herramientas adicionales
RUN dart pub global activate flutterfire_cli && \
    npm install -g firebase-tools

# Crear directorios de trabajo
RUN mkdir -p /workspace/oasistaxi && \
    chown -R flutter:flutter /workspace

# Cambiar a usuario no-root
USER flutter
WORKDIR /workspace/oasistaxi

# Script de entrada para builds
COPY --chown=flutter:flutter scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Verificar instalación
RUN flutter doctor -v && \
    java -version && \
    node --version && \
    npm --version

# Puerto para desarrollo (si se usa para dev server)
EXPOSE 3000 5000 8080

# Punto de entrada
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["flutter", "doctor"]

# ═══════════════════════════════════════════════════════════════════
# 📋 INSTRUCCIONES DE USO
# ═══════════════════════════════════════════════════════════════════

# Build de la imagen:
# docker build -t oasistaxi-flutter:latest .

# Uso para development:
# docker run -it --rm -v $(pwd):/workspace/oasistaxi oasistaxi-flutter:latest bash

# Uso para build de producción:
# docker run --rm -v $(pwd):/workspace/oasistaxi -v ~/.android:/home/flutter/.android oasistaxi-flutter:latest flutter build apk --release

# Build con secrets:
# docker run --rm \
#   -v $(pwd):/workspace/oasistaxi \
#   -v $(pwd)/secrets:/secrets \
#   -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/firebase-key.json \
#   oasistaxi-flutter:latest flutter build appbundle --release