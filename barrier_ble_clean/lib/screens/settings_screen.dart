import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  
  User? _currentUser;
  bool _biometricsAvailable = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    _currentUser = await _authService.getCurrentUser();
    _biometricsAvailable = await _authService.isBiometricsAvailable();
    setState(() {});
  }
  
  Future<void> _changePin() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              decoration: const InputDecoration(
                labelText: 'PIN actuel',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'Nouveau PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirmer le PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les PINs ne correspondent pas'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                final success = await _authService.changePin(
                  oldPinController.text,
                  newPinController.text,
                );
                
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN modifié avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _cleanOldLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer l\'historique'),
        content: const Text(
          'Supprimer tous les logs de plus de 30 jours ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final count = await _storageService.cleanOldLogs(daysToKeep: 30);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count logs supprimés'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ? Vous devrez reconfigurer l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/setup');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Section Utilisateur
                const ListTile(
                  title: Text(
                    'Utilisateur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(_currentUser!.name[0].toUpperCase()),
                        ),
                        title: Text(_currentUser!.name),
                        subtitle: Text('ID: ${_currentUser!.userId}'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.vpn_key),
                        title: const Text('Changer le PIN'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePin,
                      ),
                    ],
                  ),
                ),
                
                // Section Sécurité
                const ListTile(
                  title: Text(
                    'Sécurité',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.fingerprint),
                        title: const Text('Authentification biométrique'),
                        subtitle: Text(
                          _biometricsAvailable
                              ? 'Disponible'
                              : 'Non disponible sur cet appareil',
                        ),
                        trailing: _biometricsAvailable
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.cancel, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                // Section Données
                const ListTile(
                  title: Text(
                    'Données',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cleaning_services),
                        title: const Text('Nettoyer l\'historique'),
                        subtitle: const Text('Supprimer les logs de plus de 30 jours'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _cleanOldLogs,
                      ),
                    ],
                  ),
                ),
                
                // Section Application
                const ListTile(
                  title: Text(
                    'Application',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Version'),
                        subtitle: const Text('1.0.0'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('Paramètres BLE'),
                        subtitle: const Text(
                          'Service: 4fafc201...\nCaractéristique: beb5483e...',
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bouton de déconnexion
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                  ),
                ),
              ],
            ),
    );
  }
}
