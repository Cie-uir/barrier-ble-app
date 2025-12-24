import 'dart:convert';
import 'package:crypto/crypto.dart';

class User {
  final String userId;
  final String name;
  final String pin;
  final bool isActive;
  final DateTime createdAt;
  
  User({
    required this.userId,
    required this.name,
    required this.pin,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  // Génération du token d'authentification
  String generateToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$userId:$timestamp:$pin';
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16); // 16 caractères
  }
  
  // Création de la trame BLE à envoyer
  List<int> createBLECommand() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final token = generateToken();
    
    // Format: [USER_ID(16)][TIMESTAMP(8)][TOKEN(16)][CRC(4)]
    final userIdBytes = userId.padRight(16, '0').substring(0, 16).codeUnits;
    final timestampBytes = _int64ToBytes(timestamp);
    final tokenBytes = token.codeUnits;
    
    final command = [...userIdBytes, ...timestampBytes, ...tokenBytes];
    final crc = _calculateCRC(command);
    final crcBytes = _int32ToBytes(crc);
    
    return [...command, ...crcBytes];
  }
  
  // Conversion int64 vers bytes
  List<int> _int64ToBytes(int value) {
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
  
  // Conversion int32 vers bytes
  List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
  
  // Calcul CRC32 simple
  int _calculateCRC(List<int> data) {
    int crc = 0xFFFFFFFF;
    for (var byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc = crc >> 1;
        }
      }
    }
    return ~crc & 0xFFFFFFFF;
  }
  
  // Sérialisation JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'pin': pin,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      name: json['name'],
      pin: json['pin'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
