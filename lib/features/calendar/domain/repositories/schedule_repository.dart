import '../entities/schedule_session.dart';

abstract class ScheduleRepository {
  Stream<List<ScheduleSession>> watchSessions();

  Future<void> addSession(ScheduleSession session);

  Future<void> addSessions(List<ScheduleSession> sessions);

  Future<void> updateSession(ScheduleSession session);

  Future<void> updateSessions(List<ScheduleSession> sessions);

  Future<void> deleteSession(int id);

  /// Soft-delete all derived Upcoming sessions for a client (kept for restore).
  Future<void> deleteUpcomingSessionsForClient(String clientId);

  /// Restore previously deleted upcoming sessions for a client.
  Future<void> restoreDeletedUpcomingSessionsForClient(String clientId);

  Future<void> loadFromStorage();
}
