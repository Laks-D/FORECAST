import 'dart:convert';

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
  static const _namesKey = 'registered_program_names_v1';
  static const _detailsKey = 'registered_program_details_v1';

  static Future<List<RegisteredProgram>> getRegisteredPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detailsKey);

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

    final legacyNames = prefs.getStringList(_namesKey) ?? const <String>[];
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
      _detailsKey,
      jsonEncode(cleaned.map((p) => p.toJson()).toList(growable: false)),
    );
    await prefs.setStringList(
      _namesKey,
      cleaned.map((p) => p.name).toList(growable: false),
    );
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
