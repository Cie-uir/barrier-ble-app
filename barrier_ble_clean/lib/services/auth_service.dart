import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart';

class AuthService {
  static const String USER_KEY = 'current_user';
  static const String PIN_ATTEMPTS_KEY = 'pin_attempts';
  static const int MAX_PIN_ATTEMPTS = 3;
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Sauvegarder l'utilisateur courant
  Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      return await prefs.setString(USER_KEY, userJson);
    } catch (e) {
      print("Erreur sauvegarde utilisateur: $e");
      return false;
    }
  }
  
  // Récupérer l'utilisateur courant
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(USER_KEY);
      
      if (userJson == null) return null;
      
      final userMap = jsonDecode(userJson);
      return User.fromJson(userMap);
    } catch (e) {
      print("Erreur récupération utilisateur: $e");
      return null;
    }
  }
  
  // Vérifier le PIN
  Future<bool> verifyPin(String enteredPin) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      int attempts = prefs.getInt(PIN_ATTEMPTS_KEY) ?? 0;
      
      // Vérifier le nombre de tentatives
      if (attempts >= MAX_PIN_ATTEMPTS) {
        final lastAttemptTime = prefs.getInt('last_attempt_time') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final lockDuration = Duration(minutes: 5).inMilliseconds;
        
        if (now - lastAttemptTime < lockDuration) {
          final remainingTime = ((lockDuration - (now - lastAttemptTime)) / 60000).ceil();
          throw Exception("Trop de tentatives. Réessayez dans $remainingTime minute(s).");
        } else {
          // Reset les tentatives après le délai
          await prefs.setInt(PIN_ATTEMPTS_KEY, 0);
          attempts = 0;
        }
      }
      
      // Vérifier le PIN
      if (user.pin == enteredPin) {
        await prefs.setInt(PIN_ATTEMPTS_KEY, 0);
        return true;
      } else {
        await prefs.setInt(PIN_ATTEMPTS_KEY, attempts + 1);
        await prefs.setInt('last_attempt_time', DateTime.now().millisecondsSinceEpoch);
        return false;
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Vérifier la biométrie
  Future<bool> authenticateWithBiometrics() async {
    try {
      // Vérifier si la biométrie est disponible
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }
      
      // Authentifier
      return await _localAuth.authenticate(
        localizedReason: 'Authentification pour ouvrir la barrière',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("Erreur authentification biométrique: $e");
      return false;
    }
  }
  
  // Vérifier si la biométrie est disponible
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  // Obtenir les types de biométrie disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  // Créer un nouvel utilisateur
  Future<bool> createUser({
    required String name,
    required String userId,
    required String pin,
  }) async {
    try {
      // Valider le PIN (4-6 chiffres)
      if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
        throw Exception("Le PIN doit contenir 4 à 6 chiffres");
      }
      
      final user = User(
        userId: userId,
        name: name,
        pin: pin,
      );
      
      return await saveUser(user);
    } catch (e) {
      print("Erreur création utilisateur: $e");
      rethrow;
    }
  }
  
  // Changer le PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      
      // Vérifier l'ancien PIN
      if (user.pin != oldPin) {
        throw Exception("PIN actuel incorrect");
      }
      
      // Valider le nouveau PIN
      if (newPin.length < 4 || newPin.length > 6 || !RegExp(r'^\d+$').hasMatch(newPin)) {
        throw Exception("Le nouveau PIN doit contenir 4 à 6 chiffres");
      }
      
      // Créer un nouvel utilisateur avec le nouveau PIN
      final updatedUser = User(
        userId: user.userId,
        name: user.name,
        pin: newPin,
        isActive: user.isActive,
        createdAt: user.createdAt,
      );
      
      return await saveUser(updatedUser);
    } catch (e) {
      print("Erreur changement PIN: $e");
      rethrow;
    }
  }
  
  // Déconnexion (efface l'utilisateur local)
  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_KEY);
      await prefs.remove(PIN_ATTEMPTS_KEY);
      return true;
    } catch (e) {
      print("Erreur déconnexion: $e");
      return false;
    }
  }
  
  // Obtenir le nombre de tentatives restantes
  Future<int> getRemainingAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = prefs.getInt(PIN_ATTEMPTS_KEY) ?? 0;
    return MAX_PIN_ATTEMPTS - attempts;
  }
}
