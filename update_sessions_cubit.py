import re

with open('lib/features/calendar/bloc/sessions_cubit.dart', 'r') as f:
    content = f.read()

# Add import for RecurrenceRule
if "import '../domain/entities/recurrence_rule.dart';" not in content:
    content = content.replace("import '../domain/entities/schedule_session.dart';", "import '../domain/entities/schedule_session.dart';\nimport '../domain/entities/recurrence_rule.dart';\nimport '../domain/repositories/recurrence_rule_repository.dart';")

# Add RecurrenceRuleRepository to SessionsCubit
content = content.replace("class SessionsCubit extends Cubit<SessionsState> {", "class SessionsCubit extends Cubit<SessionsState> {\n  final RecurrenceRuleRepository recurrenceRepository;")
content = content.replace("SessionsCubit(this.repository, {ScheduleLocalDataSource? dataSource})", "SessionsCubit(this.repository, {required this.recurrenceRepository, ScheduleLocalDataSource? dataSource})")

# Add addRecurringSessions method
add_recurring = """
  Future<void> addRecurringSessions(RecurrenceRule rule, List<ScheduleSession> sessions) async {
    if (AppModeConfig.isClient) return;
    await recurrenceRepository.addRule(rule);
    await repository.addSessions(sessions);
  }
"""

content = content.replace("Future<void> addSessions(List<ScheduleSession> sessions) {", add_recurring + "\n  Future<void> addSessions(List<ScheduleSession> sessions) {")

with open('lib/features/calendar/bloc/sessions_cubit.dart', 'w') as f:
    f.write(content)

