import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/ble_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../models/access_log.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BLEService _bleService = BLEService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  
  User? _currentUser;
  BLEConnectionState _connectionState = BLEConnectionState.disconnected;
  List<String> _logs = [];
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Charger l'utilisateur
    _currentUser = await _authService.getCurrentUser();
    
    if (_currentUser == null) {
      // Pas d'utilisateur configuré - rediriger vers setup
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/setup');
      }
      return;
    }
    
    // Initialiser le BLE
    await _bleService.initialize();
    
    // Écouter les changements d'état de connexion
    _bleService.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
    
    // Écouter les logs
    _bleService.logs.listen((log) {
      if (mounted) {
        setState(() {
          _logs.insert(0, log);
          if (_logs.length > 50) {
            _logs.removeLast();
          }
        });
      }
    });
    
    setState(() {});
  }
  
  Future<void> _scanAndConnect() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await _bleService.startScan(timeout: Duration(seconds: 10));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  Future<void> _openBarrier() async {
    if (_currentUser == null || !_bleService.isConnected || _isProcessing) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    bool success = false;
    String? errorMessage;
    
    try {
      // Envoyer la commande d'ouverture
      success = await _bleService.sendOpenCommand(_currentUser!);
      
      if (!success) {
        errorMessage = "Échec de l'envoi de la commande";
      }
      
      // Enregistrer dans l'historique
      await _storageService.addAccessLog(
        AccessLog(
          userId: _currentUser!.userId,
          userName: _currentUser!.name,
          success: success,
          errorMessage: errorMessage,
        ),
      );
      
      // Afficher un message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Barrière ouverte !' : 'Échec de l\'ouverture'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      errorMessage = e.toString();
      await _storageService.addAccessLog(
        AccessLog(
          userId: _currentUser!.userId,
          userName: _currentUser!.name,
          success: false,
          errorMessage: errorMessage,
        ),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  String _getConnectionStatusText() {
    switch (_connectionState) {
      case BLEConnectionState.disconnected:
        return "Déconnecté";
      case BLEConnectionState.scanning:
        return "Recherche en cours...";
      case BLEConnectionState.connecting:
        return "Connexion...";
      case BLEConnectionState.connected:
        return "Connecté";
    }
  }
  
  Color _getConnectionStatusColor() {
    switch (_connectionState) {
      case BLEConnectionState.disconnected:
        return Colors.red;
      case BLEConnectionState.scanning:
      case BLEConnectionState.connecting:
        return Colors.orange;
      case BLEConnectionState.connected:
        return Colors.green;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôle Barrière'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // En-tête utilisateur
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        child: Text(
                          _currentUser!.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${_currentUser!.userId}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // État de connexion
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getConnectionStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getConnectionStatusText(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_connectionState == BLEConnectionState.scanning ||
                          _connectionState == BLEConnectionState.connecting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                
                // Boutons principaux
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Bouton d'ouverture
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: ElevatedButton(
                          onPressed: _bleService.isConnected && !_isProcessing
                              ? _openBarrier
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isProcessing
                              ? const SpinKitCircle(color: Colors.white, size: 50)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_open, size: 48),
                                    SizedBox(height: 8),
                                    Text(
                                      'OUVRIR',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bouton de connexion/déconnexion
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : (_bleService.isConnected
                                  ? () => _bleService.disconnect()
                                  : _scanAndConnect),
                          icon: Icon(_bleService.isConnected
                              ? Icons.bluetooth_disabled
                              : Icons.bluetooth_searching),
                          label: Text(_bleService.isConnected
                              ? 'Déconnecter'
                              : 'Rechercher barrière'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Logs
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Journal de communication',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[300]),
                        Expanded(
                          child: _logs.isEmpty
                              ? Center(
                                  child: Text(
                                    'Aucun événement',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _logs.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        _logs[index],
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
}
