class AccessLog {
  final int? id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;
  
  AccessLog({
    this.id,
    required this.userId,
    required this.userName,
    DateTime? timestamp,
    required this.success,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp.toIso8601String(),
      'success': success ? 1 : 0,
      'errorMessage': errorMessage,
    };
  }
  
  factory AccessLog.fromMap(Map<String, dynamic> map) {
    return AccessLog(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      timestamp: DateTime.parse(map['timestamp']),
      success: map['success'] == 1,
      errorMessage: map['errorMessage'],
    );
  }
  
  String getStatusText() {
    return success ? 'Ouverture réussie' : 'Échec: ${errorMessage ?? "Erreur inconnue"}';
  }
}
