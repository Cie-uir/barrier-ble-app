import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/user.dart';

class BLEService {
  // UUIDs personnalisés - À synchroniser avec l'ESP32
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String DEVICE_NAME = "BARRIER_CTRL";
  
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  
  // État de la connexion
  final StreamController<BLEConnectionState> _connectionStateController = 
      StreamController<BLEConnectionState>.broadcast();
  Stream<BLEConnectionState> get connectionState => _connectionStateController.stream;
  
  // Logs de communication
  final StreamController<String> _logController = 
      StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;
  
  BLEConnectionState _currentState = BLEConnectionState.disconnected;
  
  // Initialisation du BLE
  Future<bool> initialize() async {
    try {
      // Vérifier si BLE est supporté
      if (await FlutterBluePlus.isSupported == false) {
        _log("BLE non supporté sur cet appareil");
        return false;
      }
      
      // Vérifier l'état du Bluetooth
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _log("Bluetooth désactivé - Activation en cours...");
        await FlutterBluePlus.turnOn();
        await Future.delayed(Duration(seconds: 2));
      }
      
      _log("BLE initialisé avec succès");
      return true;
    } catch (e) {
      _log("Erreur initialisation BLE: $e");
      return false;
    }
  }
  
  // Scanner les appareils à proximité
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      _updateState(BLEConnectionState.scanning);
      _log("Démarrage du scan BLE...");
      
      // Arrêter un scan en cours
      await FlutterBluePlus.stopScan();
      
      // Démarrer le nouveau scan
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
      
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName.contains(DEVICE_NAME)) {
            _log("Barrière trouvée: ${r.device.platformName}");
            connectToDevice(r.device);
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });
      
      // Timeout du scan
      Future.delayed(timeout, () {
        if (_currentState == BLEConnectionState.scanning) {
          FlutterBluePlus.stopScan();
          _updateState(BLEConnectionState.disconnected);
          _log("Scan terminé - Aucune barrière trouvée");
        }
      });
      
    } catch (e) {
      _log("Erreur pendant le scan: $e");
      _updateState(BLEConnectionState.disconnected);
    }
  }
  
  // Connexion à un appareil
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _updateState(BLEConnectionState.connecting);
      _log("Connexion à ${device.platformName}...");
      
      // Se connecter avec timeout
      await device.connect(
        timeout: Duration(seconds: 15),
        autoConnect: false,
      );
      
      _connectedDevice = device;
      
      // Écouter les déconnexions
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log("Appareil déconnecté");
          _updateState(BLEConnectionState.disconnected);
          _cleanup();
        }
      });
      
      // Découvrir les services
      _log("Découverte des services...");
      List<BluetoothService> services = await device.discoverServices();
      
      // Trouver notre service et caractéristique
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          _log("Service trouvé");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _commandCharacteristic = characteristic;
              _log("Caractéristique de commande trouvée");
              _updateState(BLEConnectionState.connected);
              return true;
            }
          }
        }
      }
      
      _log("Service/Caractéristique non trouvé");
      await disconnect();
      return false;
      
    } catch (e) {
      _log("Erreur de connexion: $e");
      _updateState(BLEConnectionState.disconnected);
      return false;
    }
  }
  
  // Envoyer une commande d'ouverture
  Future<bool> sendOpenCommand(User user) async {
    if (_commandCharacteristic == null) {
      _log("Pas de connexion active");
      return false;
    }
    
    try {
      _log("Envoi commande d'ouverture...");
      
      // Créer la trame de commande
      List<int> command = user.createBLECommand();
      
      // Envoyer la commande
      await _commandCharacteristic!.write(
        command,
        withoutResponse: false,
      );
      
      _log("Commande envoyée avec succès (${command.length} bytes)");
      
      // Attendre une confirmation (optionnel - si l'ESP32 envoie une réponse)
      await Future.delayed(Duration(milliseconds: 500));
      
      return true;
      
    } catch (e) {
      _log("Erreur envoi commande: $e");
      return false;
    }
  }
  
  // Déconnexion
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        _log("Déconnexion...");
        await _connectedDevice!.disconnect();
      }
      _cleanup();
    } catch (e) {
      _log("Erreur déconnexion: $e");
    }
  }
  
  // Nettoyage des ressources
  void _cleanup() {
    _connectedDevice = null;
    _commandCharacteristic = null;
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _updateState(BLEConnectionState.disconnected);
  }
  
  // Mise à jour de l'état
  void _updateState(BLEConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }
  
  // Logging
  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add("[$timestamp] $message");
    print("[BLE] $message");
  }
  
  // Dispose
  void dispose() {
    _connectionStateController.close();
    _logController.close();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
  
  // Getter pour l'état actuel
  BLEConnectionState get currentState => _currentState;
  bool get isConnected => _currentState == BLEConnectionState.connected;
}

// États de connexion BLE
enum BLEConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}
