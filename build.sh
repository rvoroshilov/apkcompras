#!/bin/bash
# Script para construir el APK de MiCompra
# Requiere Flutter instalado: https://flutter.dev/docs/get-started/install

set -e

echo "=== MiCompra Build Script ==="

# Verificar Flutter
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter no está instalado."
    echo "Instala Flutter desde: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "Flutter version:"
flutter --version

echo ""
echo "Instalando dependencias..."
flutter pub get

echo ""
echo "Construyendo APK (release)..."
flutter build apk --release

echo ""
echo "=== APK generado exitosamente ==="
echo "Ubicación: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Para instalar en tu dispositivo:"
echo "  flutter install"
echo "  o copia el APK a tu dispositivo y ábrelo."
