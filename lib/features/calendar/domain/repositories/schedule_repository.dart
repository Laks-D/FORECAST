import '../entities/schedule_session.dart';

abstract class ScheduleRepository {
  Stream<List<ScheduleSession>> watchSessions();

  Future<void> addSession(ScheduleSession session);

  Future<void> addSessions(List<ScheduleSession> sessions);

  Future<void> updateSession(ScheduleSession session);

  Future<void> deleteSession(int id);

  Future<void> loadFromStorage();
}
