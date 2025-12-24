import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/access_log.dart';

class StorageService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'barrier_access.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE access_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            userName TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            success INTEGER NOT NULL,
            errorMessage TEXT
          )
        ''');
      },
    );
  }
  
  // Ajouter un log d'accès
  Future<int> addAccessLog(AccessLog log) async {
    final db = await database;
    return await db.insert('access_logs', log.toMap());
  }
  
  // Récupérer tous les logs (limité aux 100 derniers)
  Future<List<AccessLog>> getAccessLogs({int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'access_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return List.generate(maps.length, (i) {
      return AccessLog.fromMap(maps[i]);
    });
  }
  
  // Récupérer les logs d'un utilisateur spécifique
  Future<List<AccessLog>> getUserLogs(String userId, {int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'access_logs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return List.generate(maps.length, (i) {
      return AccessLog.fromMap(maps[i]);
    });
  }
  
  // Supprimer les anciens logs (plus de 30 jours)
  Future<int> cleanOldLogs({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    return await db.delete(
      'access_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }
  
  // Obtenir des statistiques
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    
    // Nombre total d'accès
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM access_logs');
    final total = totalResult.first['count'] as int;
    
    // Nombre d'accès réussis
    final successResult = await db.rawQuery('SELECT COUNT(*) as count FROM access_logs WHERE success = 1');
    final success = successResult.first['count'] as int;
    
    // Dernier accès
    final lastAccessResult = await db.query(
      'access_logs',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    DateTime? lastAccess;
    if (lastAccessResult.isNotEmpty) {
      lastAccess = DateTime.parse(lastAccessResult.first['timestamp'] as String);
    }
    
    return {
      'total': total,
      'success': success,
      'failed': total - success,
      'successRate': total > 0 ? (success / total * 100).toStringAsFixed(1) : '0.0',
      'lastAccess': lastAccess,
    };
  }
}
