# Barrier BLE App - Application de Contrôle de Barrière

Application Flutter pour contrôler une barrière via Bluetooth Low Energy (BLE).

## 🚀 Fonctionnalités

- ✅ Authentification locale (PIN + biométrie)
- ✅ Connexion BLE sécurisée avec ESP32
- ✅ Protocole cryptographique SHA-256
- ✅ Historique des accès avec SQLite
- ✅ Interface Material Design 3

## 📱 Configuration Requise

- Android 6.0+ avec BLE
- Permissions: Bluetooth, Localisation, Biométrie

## 🔧 Installation

1. Télécharger `app-release.apk` depuis GitHub Actions
2. Installer sur le smartphone
3. Configuration première utilisation :
   - Nom complet
   - User ID (doit correspondre à l'ESP32)
   - PIN (4-6 chiffres)

## 🔐 Protocole BLE

Trame de 44 bytes:
- USER_ID: 16 bytes
- TIMESTAMP: 8 bytes
- TOKEN SHA-256: 16 bytes
- CRC32: 4 bytes

## 📡 ESP32

Code disponible dans `esp32_controller/barrier_controller.ino`

UUIDs:
- Service: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Characteristic: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

## 🏗️ Compilation

GitHub Actions compile automatiquement l'APK à chaque push.

## 📝 Licence

Projet CIE-UIR
