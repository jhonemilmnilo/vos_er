import "dart:convert";

import "package:crypto/crypto.dart";
import "package:shared_preferences/shared_preferences.dart";

class CachedUser {
  final int userId;
  final String email;
  final String passwordHash; // hashed locally
  final String? fname;
  final String? lname;

  const CachedUser({
    required this.userId,
    required this.email,
    required this.passwordHash,
    this.fname,
    this.lname,
  });

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "user_email": email,
    "password_hash": passwordHash,
    "user_fname": fname,
    "user_lname": lname,
  };

  static CachedUser fromJson(Map<String, dynamic> j) => CachedUser(
    userId: (j["user_id"] as num).toInt(),
    email: (j["user_email"] ?? "").toString(),
    passwordHash: (j["password_hash"] ?? "").toString(),
    fname: j["user_fname"]?.toString(),
    lname: j["user_lname"]?.toString(),
  );
}

class AuthStorage {
  static const _kUserId = "auth.current_user_id";
  static const _kCachedUsers = "auth.cached_users";

  // ---- Seeder: offline default account ----
  static const int _seedUserId = 207;
  static const String _seedEmail = "norman_delfin@men2corp.com";
  static const String _seedPassword = "delfin123";
  static const String _seedFname = "Norman";
  static const String _seedLname = "Delfin";

  static String hashPassword(String plain) {
    final bytes = utf8.encode(plain);
    return sha256.convert(bytes).toString();
  }

  Future<void> seedOfflineUserIfMissing() async {
    final list = await readCachedUsers();
    final seedEmailLower = _seedEmail.trim().toLowerCase();

    final exists = list.any((u) => u.email.trim().toLowerCase() == seedEmailLower);
    if (exists) return;

    final seeded = CachedUser(
      userId: _seedUserId,
      email: _seedEmail,
      passwordHash: hashPassword(_seedPassword),
      fname: _seedFname,
      lname: _seedLname,
    );

    await upsertCachedUser(seeded);
  }

  Future<void> saveUserId(int userId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kUserId, userId);
  }

  Future<int?> readUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }

  Future<void> clearUserId() async {
    final sp = await SharedPreferences.getInstance();

    // Remove the current user from the cache to ensure credentials are destroyed
    final currentUserId = sp.getInt(_kUserId);
    if (currentUserId != null) {
      final list = await readCachedUsers();
      final updated = list.where((u) => u.userId != currentUserId).toList();
      await sp.setString(_kCachedUsers, jsonEncode(updated.map((e) => e.toJson()).toList()));
    }

    await sp.remove(_kUserId);
  }

  Future<List<CachedUser>> readCachedUsers() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kCachedUsers);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => CachedUser.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertCachedUser(CachedUser user) async {
    final sp = await SharedPreferences.getInstance();
    final list = await readCachedUsers();

    final emailLower = user.email.trim().toLowerCase();
    final updated = <CachedUser>[
      for (final u in list)
        if (u.email.trim().toLowerCase() != emailLower) u,
      user,
    ];

    await sp.setString(_kCachedUsers, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);

    // Destroy all cached credentials to prevent any remnants of previous sessions
    await sp.remove(_kCachedUsers);
  }

  Future<void> saveRememberMe(
    String departmentName,
    bool remember,
    String email,
    String password,
  ) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('remember_me_$departmentName', remember);
    if (remember) {
      await sp.setString('remember_email_$departmentName', email);
      await sp.setString('remember_password_$departmentName', password);
    } else {
      await sp.remove('remember_email_$departmentName');
      await sp.remove('remember_password_$departmentName');
    }
  }

  Future<Map<String, String?>> loadRememberMe(String departmentName) async {
    final sp = await SharedPreferences.getInstance();
    final remember = sp.getBool('remember_me_$departmentName') ?? false;
    final email = sp.getString('remember_email_$departmentName');
    final password = sp.getString('remember_password_$departmentName');
    return {'remember': remember.toString(), 'email': email, 'password': password};
  }
}
