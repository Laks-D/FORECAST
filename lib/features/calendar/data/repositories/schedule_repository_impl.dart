import '../../domain/entities/schedule_session.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_local_datasource.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleLocalDataSource local;

  const ScheduleRepositoryImpl(this.local);

  @override
  Stream<List<ScheduleSession>> watchSessions() => local.watchSessions();

  @override
  Future<void> addSession(ScheduleSession session) => local.addSession(session);

  @override
  Future<void> addSessions(List<ScheduleSession> sessions) =>
      local.addSessions(sessions);

  @override
  Future<void> updateSession(ScheduleSession session) =>
      local.updateSession(session);

    @override
    Future<void> updateSessions(List<ScheduleSession> sessions) =>
      local.updateSessions(sessions);

  @override
  Future<void> deleteSession(int id) => local.deleteSession(id);

  @override
  Future<void> deleteUpcomingSessionsForClient(String clientId) {
    return local.deleteUpcomingSessionsForClient(clientId);
  }

  @override
  Future<void> restoreDeletedUpcomingSessionsForClient(String clientId) {
    return local.restoreDeletedUpcomingSessionsForClient(clientId);
  }

  @override
  Future<void> loadFromStorage() => local.loadFromStorage();
}
