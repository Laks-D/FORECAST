import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisteredProgram {
  const RegisteredProgram({
    required this.name,
    this.description = '',
    this.frequency = 'Weekly',
    this.numberOfClasses = 8,
    this.classDuration = '1 Hour',
    this.customDays = 1,
  });

  final String name;
  final String description;
  final String frequency;
  final int numberOfClasses;
  final String classDuration;
  final int customDays;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'frequency': frequency,
        'numberOfClasses': numberOfClasses,
        'classDuration': classDuration,
        'customDays': customDays,
      };

  factory RegisteredProgram.fromJson(Map<String, dynamic> json) {
    return RegisteredProgram(
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      frequency: (json['frequency'] as String? ?? 'Weekly').trim(),
      numberOfClasses: (json['numberOfClasses'] as num?)?.toInt() ?? 8,
      classDuration: (json['classDuration'] as String? ?? '1 Hour').trim(),
      customDays: (json['customDays'] as num?)?.toInt() ?? 1,
    );
  }
}

class ProgramCatalogStorage {
  static const _namesKeyBase = 'registered_program_names_v1';
  static const _detailsKeyBase = 'registered_program_details_v1';

  static String _uidSuffix([String? uid]) {
    final resolved = uid ?? FirebaseAuth.instance.currentUser?.uid;
    return resolved == null || resolved.trim().isEmpty ? '_signed_out' : '_$resolved';
  }

  static String _namesKey([String? uid]) => '$_namesKeyBase${_uidSuffix(uid)}';
  static String _detailsKey([String? uid]) => '$_detailsKeyBase${_uidSuffix(uid)}';

  /// Legacy (non user-scoped) keys.
  static const _legacyNamesKey = _namesKeyBase;
  static const _legacyDetailsKey = _detailsKeyBase;

  static Future<List<RegisteredProgram>> getRegisteredPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detailsKey());

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => RegisteredProgram.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.name.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {}
    }

    // If we are signed in but data was accidentally saved while signed out
    // (e.g., brief auth timing gap), migrate it into the signed-in key.
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && currentUid.trim().isNotEmpty) {
      final signedOutRaw = prefs.getString(_detailsKey('signed_out'));
      if (signedOutRaw != null && signedOutRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(signedOutRaw);
          if (decoded is List) {
            await overwriteFromJsonList(decoded, uid: currentUid);
            await prefs.remove(_detailsKey('signed_out'));
            await prefs.remove(_namesKey('signed_out'));
            return decoded
                .whereType<Map>()
                .map((e) => RegisteredProgram.fromJson(Map<String, dynamic>.from(e)))
                .where((e) => e.name.isNotEmpty)
                .toList(growable: false);
          }
        } catch (_) {}
      }
    }

    // One-time migration from legacy (non-scoped) key.
    final legacyRaw = prefs.getString(_legacyDetailsKey);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is List) {
          final migrated = decoded
              .whereType<Map>()
              .map((e) => RegisteredProgram.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.name.isNotEmpty)
              .toList(growable: false);
          if (migrated.isNotEmpty) {
            await saveRegisteredPrograms(migrated);
            return migrated;
          }
        }
      } catch (_) {}
    }

    final legacyNames = prefs.getStringList(_namesKey()) ??
        prefs.getStringList(_legacyNamesKey) ??
        const <String>[];
    return legacyNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => RegisteredProgram(name: e))
        .toList(growable: false);
  }

  static Future<void> saveRegisteredPrograms(List<RegisteredProgram> programs) async {
    final prefs = await SharedPreferences.getInstance();

    final cleaned = programs.where((p) => p.name.trim().isNotEmpty).toList(growable: false);

    await prefs.setString(
      _detailsKey(),
      jsonEncode(cleaned.map((p) => p.toJson()).toList(growable: false)),
    );
    await prefs.setStringList(
      _namesKey(),
      cleaned.map((p) => p.name).toList(growable: false),
    );
  }

  /// Overwrite local catalog from a Firestore-provided JSON list.
  /// Expected element shape matches [RegisteredProgram.toJson].
  static Future<void> overwriteFromJsonList(List<dynamic> jsonList, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = jsonList
        .whereType<Map>()
        .map((e) => RegisteredProgram.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.name.isNotEmpty)
        .toList(growable: false);

    await prefs.setString(
      _detailsKey(uid),
      jsonEncode(cleaned.map((p) => p.toJson()).toList(growable: false)),
    );
    await prefs.setStringList(
      _namesKey(uid),
      cleaned.map((p) => p.name).toList(growable: false),
    );
  }

  static List<Map<String, dynamic>> toJsonList(List<RegisteredProgram> programs) {
    return programs
        .where((p) => p.name.trim().isNotEmpty)
        .map((p) => p.toJson())
        .toList(growable: false);
  }

  static Future<List<String>> getPrograms() async {
    final programs = await getRegisteredPrograms();
    return programs
        .map((e) => e.name)
        .toList(growable: false);
  }

  static Future<void> savePrograms(List<String> programNames) async {
    final cleaned = programNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    await saveRegisteredPrograms(
      cleaned.map((e) => RegisteredProgram(name: e)).toList(growable: false),
    );
  }
}
