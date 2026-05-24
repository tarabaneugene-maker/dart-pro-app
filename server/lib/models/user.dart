/// Модель пользователя
class User {
  final String id;
  final String login;
  final String displayName;
  final String passwordHash;
  final DateTime createdAt;

  User({
    required this.id,
    required this.login,
    required this.displayName,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'login': login,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
      };
}
