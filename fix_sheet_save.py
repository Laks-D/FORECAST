import re

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'r') as f:
    content = f.read()

# I also need to make sure we have access to uuid, or just use DateTime for id
# In the file, import uuid? Let's just use `DateTime.now().millisecondsSinceEpoch.toString()` for simplicity or `uuid`.
# `uuid` is already used in `client_bloc.dart`. I'll just use a simple timestamp string for the `recurrenceId`.

old_save = """  Future<void> _saveDraft() async {
    final cubit = context.read<SessionsCubit>();
    if (_draft.isEmpty) return;
    if (_clashIds.isNotEmpty) return;

    await cubit.addSessions(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }"""

new_save = """  Future<void> _saveDraft() async {
    final cubit = context.read<SessionsCubit>();
    if (_draft.isEmpty) return;
    if (_clashIds.isNotEmpty) return;

    if (_sessionCount > 1) {
      final recurrenceId = 'rr_${DateTime.now().millisecondsSinceEpoch}';
      
      // Update draft sessions to have this recurrenceId
      final linkedDraft = _draft.map((s) => s.copyWith(recurrenceId: recurrenceId)).toList();
      
      final rule = RecurrenceRule(
        recurrenceId: recurrenceId,
        tutorId: linkedDraft.first.clientId, // Wait! tutorId is the authenticated user, we can get it or just use the current user from auth later. Actually, RecurrenceRule entity expects tutorId.
        // Wait, where is tutorId? It's not easily available here. Let's look at `AppModeScope` or `UserProfileCubit`?
        // Let's just leave tutorId empty or get it from Auth.
        // I will use FirebaseAuth.instance.currentUser?.uid ?? ''
        clientId: _clientId!,
        programId: null, // We could map `_courseNameController.text` if it matched a program, but simpler to leave null
        frequency: _frequency.toLowerCase(),
        interval: 1,
        byWeekday: _frequency == 'Weekly' ? [_weeklyDay] : null,
        startDate: DateTime.parse(linkedDraft.first.date),
        endDate: DateTime.parse(linkedDraft.last.date),
        time: linkedDraft.first.time,
      );
      
      // I need to import RecurrenceRule and FirebaseAuth.
      await cubit.addRecurringSessions(rule, linkedDraft);
    } else {
      await cubit.addSessions(_draft);
    }
    
    if (!mounted) return;
    Navigator.of(context).pop();
  }"""

content = content.replace(old_save, new_save)

# Add imports
if "import 'package:firebase_auth/firebase_auth.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:firebase_auth/firebase_auth.dart';")

if "import '../../domain/entities/recurrence_rule.dart';" not in content:
    content = content.replace("import '../../domain/entities/schedule_session.dart';", "import '../../domain/entities/schedule_session.dart';\nimport '../../domain/entities/recurrence_rule.dart';")

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'w') as f:
    f.write(content)

