import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_firestore_sync.dart';
import '../../features/course/data/program_repository.dart';
import '../../features/course/domain/entities/program.dart';

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
  static const _settingsKey = 'programCatalog';

  static Future<List<RegisteredProgram>> getRegisteredPrograms() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?[_settingsKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => RegisteredProgram.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList(growable: false);
    }
    return const <RegisteredProgram>[];
  }

  static Future<void> saveRegisteredPrograms(List<RegisteredProgram> programs) async {
    final cleaned = programs.where((p) => p.name.trim().isNotEmpty).toList(growable: false);
    await UserFirestoreSync.instance.patchSettingsNow({
      _settingsKey: cleaned.map((p) => p.toJson()).toList(growable: false),
    });
    // Phase 5 dual-write: mirror into the programs sub-collection (settings
    // array stays the read source). Guarded.
    unawaited(_mirrorToProgramsCollection(cleaned));
  }

  static Future<void> _mirrorToProgramsCollection(
      List<RegisteredProgram> programs) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return;
      final mapped = programs
          .map((p) => Program(
                programId: Program.slug(p.name),
                tutorId: uid,
                name: p.name,
                description: p.description,
                frequency: p.frequency,
                numberOfClasses: p.numberOfClasses,
                classDuration: p.classDuration,
                customDays: p.customDays,
              ))
          .toList(growable: false);
      await FirestoreProgramRepository().replaceAll(mapped);
    } catch (_) {
      // Non-critical mirror.
    }
  }

  static List<Map<String, dynamic>> toJsonList(List<RegisteredProgram> programs) {
    return programs
        .where((p) => p.name.trim().isNotEmpty)
        .map((p) => p.toJson())
        .toList(growable: false);
  }

  static Future<List<String>> getPrograms() async {
    final programs = await getRegisteredPrograms();
    return programs.map((e) => e.name).toList(growable: false);
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
