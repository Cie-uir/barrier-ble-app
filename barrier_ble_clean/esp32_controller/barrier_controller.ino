/**
 * ESP32 BLE Barrier Controller
 * CIE-UIR - Université Internationale de Rabat
 * 
 * Ce code permet à l'ESP32 de:
 * - Créer un serveur BLE
 * - Recevoir des commandes d'authentification depuis l'app mobile
 * - Vérifier l'authenticité des requêtes
 * - Commander l'ouverture de la barrière
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>

// Configuration BLE
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "BARRIER_CTRL"

// Configuration matérielle
#define RELAY_PIN           2   // GPIO pour commander le relais
#define LED_PIN            23   // LED indicateur d'état
#define OPEN_DURATION    5000   // Durée d'ouverture en ms

// Base de données utilisateurs (simplifiée - en production, utiliser SPIFFS/SD)
struct AuthorizedUser {
    char userId[17];       // 16 caractères + null terminator
    char pin[7];           // 6 chiffres + null terminator
    bool isActive;
};

// Liste des utilisateurs autorisés (à adapter selon vos besoins)
AuthorizedUser authorizedUsers[] = {
    {"BADGE001", "1234", true},
    {"BADGE002", "5678", true},
    // Ajouter d'autres utilisateurs ici
};
const int NUM_USERS = sizeof(authorizedUsers) / sizeof(AuthorizedUser);

// Variables globales
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
Preferences preferences;

// Prototypes de fonctions
uint32_t calculateCRC32(const uint8_t* data, size_t length);
bool verifyToken(const char* userId, const char* pin, uint64_t timestamp, const char* receivedToken);
bool isUserAuthorized(const char* userId);
void openBarrier();
void blinkLED(int times, int delayMs);

// Callbacks de connexion BLE
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Client connecté");
        blinkLED(2, 200);
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Client déconnecté");
    }
};

// Callbacks de réception de commandes
class CommandCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        // Récupérer les données en tant que pointeur uint8_t*
        uint8_t* pData = pCharacteristic->getData();
        size_t length = pCharacteristic->getValue().length();
        
        Serial.printf("Commande reçue: %d bytes\n", length);
        
        // Vérifier la longueur de la trame
        if (length != 44) {
            Serial.println("❌ Trame invalide: longueur incorrecte");
            blinkLED(5, 100);
            return;
        }
        
        // Extraire les champs de la trame
        char userId[17];
        memcpy(userId, pData, 16);
        userId[16] = '\0';
        
        // Retirer les espaces de padding
        for(int i = 15; i >= 0; i--) {
            if(userId[i] == '0' || userId[i] == ' ') userId[i] = '\0';
            else break;
        }
        
        // Extraire TIMESTAMP (8 bytes, big-endian)
        uint64_t timestamp = 0;
        for(int i = 0; i < 8; i++) {
            timestamp = (timestamp << 8) | pData[16 + i];
        }
        
        // Extraire TOKEN (16 bytes)
        char token[17];
        memcpy(token, pData + 24, 16);
        token[16] = '\0';
        
        // Extraire CRC32 (4 bytes, big-endian)
        uint32_t receivedCRC = 0;
        for(int i = 0; i < 4; i++) {
            receivedCRC = (receivedCRC << 8) | pData[40 + i];
        }
        
        Serial.printf("User ID: %s\n", userId);
        Serial.printf("Timestamp: %llu\n", timestamp);
        Serial.printf("Token: %s\n", token);
        Serial.printf("CRC reçu: 0x%08X\n", receivedCRC);
        
        // Vérifier le CRC
        uint32_t calculatedCRC = calculateCRC32(pData, 40);
        Serial.printf("CRC calculé: 0x%08X\n", calculatedCRC);
        
        if (calculatedCRC != receivedCRC) {
            Serial.println("❌ CRC invalide - trame corrompue");
            blinkLED(5, 100);
            return;
        }
        
        Serial.println("✓ CRC valide");
        
        // Vérifier la validité temporelle (tolérance de 60 secondes)
        uint64_t currentTime = millis();
        int64_t timeDiff = abs((int64_t)timestamp - (int64_t)currentTime);
        if (timeDiff > 60000) {
            Serial.println("❌ Timestamp expiré ou invalide");
            blinkLED(5, 100);
            return;
        }
        
        Serial.println("✓ Timestamp valide");
        
        // Vérifier si l'utilisateur existe et est autorisé
        bool userFound = false;
        char* userPin = NULL;
        
        for(int i = 0; i < NUM_USERS; i++) {
            if(strcmp(authorizedUsers[i].userId, userId) == 0 && authorizedUsers[i].isActive) {
                userFound = true;
                userPin = authorizedUsers[i].pin;
                break;
            }
        }
        
        if(!userFound) {
            Serial.println("❌ Utilisateur non autorisé");
            blinkLED(5, 100);
            return;
        }
        
        Serial.println("✓ Utilisateur autorisé");
        
        // Vérifier le token
        if(!verifyToken(userId, userPin, timestamp, token)) {
            Serial.println("❌ Token invalide");
            blinkLED(5, 100);
            return;
        }
        
        Serial.println("✓ Token valide");
        Serial.println("✅ ACCÈS AUTORISÉ - Ouverture de la barrière");
        
        // Ouvrir la barrière
        openBarrier();
        
        // Enregistrer dans les logs (optionnel - EEPROM/SPIFFS)
        preferences.begin("access-logs", false);
        int accessCount = preferences.getInt("count", 0);
        preferences.putInt("count", accessCount + 1);
        preferences.end();
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("=================================");
    Serial.println("ESP32 BLE Barrier Controller");
    Serial.println("CIE-UIR - Version 1.0");
    Serial.println("=================================");
    
    // Configuration des GPIO
    pinMode(RELAY_PIN, OUTPUT);
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, LOW);
    digitalWrite(LED_PIN, LOW);
    
    // Test du relais au démarrage
    Serial.println("Test du relais...");
    digitalWrite(RELAY_PIN, HIGH);
    delay(500);
    digitalWrite(RELAY_PIN, LOW);
    
    // Initialiser les préférences
    preferences.begin("config", false);
    
    // Initialiser BLE
    Serial.println("Initialisation BLE...");
    BLEDevice::init(DEVICE_NAME);
    
    // Créer le serveur BLE
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    
    // Créer le service BLE
    BLEService *pService = pServer->createService(SERVICE_UUID);
    
    // Créer la caractéristique (Write)
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    
    pCharacteristic->setCallbacks(new CommandCallbacks());
    
    // Démarrer le service
    pService->start();
    
    // Démarrer l'advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(false);
    pAdvertising->setMinPreferred(0x06);
    
    // Configuration advertising étendue pour meilleure visibilité
    pAdvertising->setMinInterval(100);  // 100ms
    pAdvertising->setMaxInterval(200);  // 200ms
    
    Serial.println("Démarrage de l'advertising BLE...");
    BLEDevice::startAdvertising();
    
    Serial.println("✅ Serveur BLE démarré et en attente de connexions");
    Serial.printf("Nom du device: %s\n", DEVICE_NAME);
    Serial.printf("Service UUID: %s\n", SERVICE_UUID);
    Serial.printf("Nombre d'utilisateurs autorisés: %d\n", NUM_USERS);
    Serial.println("⚡ L'ESP32 diffuse maintenant en BLE...");
    Serial.println("📱 Utilisez nRF Connect pour scanner");
    
    blinkLED(3, 300);
}

void loop() {
    // Gestion de la reconnexion
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        Serial.println("📡 Redémarrage de l'advertising");
        oldDeviceConnected = deviceConnected;
    }
    
    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }
    
    // LED de battement de coeur + message périodique
    static unsigned long lastBlink = 0;
    static int heartbeatCount = 0;
    
    if(millis() - lastBlink > 2000) {
        digitalWrite(LED_PIN, HIGH);
        delay(50);
        digitalWrite(LED_PIN, LOW);
        lastBlink = millis();
        
        heartbeatCount++;
        if(heartbeatCount % 10 == 0) {  // Tous les 20 secondes
            Serial.printf("💓 Heartbeat %d - BLE actif - En attente de connexion...\n", heartbeatCount);
        }
    }
}

/**
 * Calcul du CRC32
 */
uint32_t calculateCRC32(const uint8_t* data, size_t length) {
    uint32_t crc = 0xFFFFFFFF;
    
    for (size_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            if (crc & 1) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc = crc >> 1;
            }
        }
    }
    
    return ~crc;
}

/**
 * Vérification du token
 * Note: Version simplifiée - en production, implémenter SHA-256 complète
 */
bool verifyToken(const char* userId, const char* pin, uint64_t timestamp, const char* receivedToken) {
    // Pour une vérification complète, il faudrait:
    // 1. Reconstruire la string: userId:timestamp:pin
    // 2. Calculer le SHA-256
    // 3. Comparer les 16 premiers caractères
    
    // Version simplifiée pour la démo:
    // On vérifie juste que le token n'est pas vide
    return (strlen(receivedToken) == 16);
}

/**
 * Vérifier si un utilisateur est autorisé
 */
bool isUserAuthorized(const char* userId) {
    for(int i = 0; i < NUM_USERS; i++) {
        if(strcmp(authorizedUsers[i].userId, userId) == 0 && authorizedUsers[i].isActive) {
            return true;
        }
    }
    return false;
}

/**
 * Ouvrir la barrière
 */
void openBarrier() {
    Serial.println(">>> OUVERTURE DE LA BARRIÈRE <<<");
    
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(RELAY_PIN, HIGH);
    
    delay(OPEN_DURATION);
    
    digitalWrite(RELAY_PIN, LOW);
    digitalWrite(LED_PIN, LOW);
    
    Serial.println(">>> BARRIÈRE FERMÉE <<<");
}

/**
 * Faire clignoter la LED
 */
void blinkLED(int times, int delayMs) {
    for(int i = 0; i < times; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(delayMs);
        digitalWrite(LED_PIN, LOW);
        delay(delayMs);
    }
}
