import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _biometricsAvailable = false;
  int _remainingAttempts = 3;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _updateRemainingAttempts();
  }

  Future<void> _checkBiometrics() async {
    final available = await _authService.isBiometricsAvailable();
    setState(() {
      _biometricsAvailable = available;
    });
    
    // Proposer automatiquement la biométrie si disponible
    if (available) {
      Future.delayed(Duration(milliseconds: 500), _authenticateWithBiometrics);
    }
  }
  
  Future<void> _updateRemainingAttempts() async {
    final remaining = await _authService.getRemainingAttempts();
    setState(() {
      _remainingAttempts = remaining;
    });
  }

  Future<void> _authenticateWithPin() async {
    if (_pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer votre PIN'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.verifyPin(_pinController.text);
      
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        await _updateRemainingAttempts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PIN incorrect. $_remainingAttempts tentative(s) restante(s)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          _pinController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.authenticateWithBiometrics();
      
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentification biométrique échouée'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(
                  Icons.lock_outline,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Authentification',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Entrez votre PIN pour accéder à l\'application',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Champ PIN
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'Code PIN',
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscurePin = !_obscurePin;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
                    maxLength: 6,
                    autofocus: true,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _authenticateWithPin(),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Tentatives restantes
                if (_remainingAttempts < 3)
                  Text(
                    '$_remainingAttempts tentative(s) restante(s)',
                    style: TextStyle(
                      color: _remainingAttempts == 1 ? Colors.red : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Bouton de connexion
                SizedBox(
                  width: 280,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticateWithPin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                // Biométrie
                if (_biometricsAvailable) ...[
                  const SizedBox(height: 24),
                  
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OU'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _authenticateWithBiometrics,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text(
                      'Authentification biométrique',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
