import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/schedule_session.dart';
import '../domain/repositories/schedule_repository.dart';

final class SessionsState extends Equatable {
  const SessionsState({
    required this.isLoading,
    required this.sessions,
    this.error,
  });

  final bool isLoading;
  final List<ScheduleSession> sessions;
  final String? error;

  SessionsState copyWith({
    bool? isLoading,
    List<ScheduleSession>? sessions,
    String? error,
  }) {
    return SessionsState(
      isLoading: isLoading ?? this.isLoading,
      sessions: sessions ?? this.sessions,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, sessions, error];
}

class SessionsCubit extends Cubit<SessionsState> {
  final ScheduleRepository repository;
  StreamSubscription<List<ScheduleSession>>? _sub;

  SessionsCubit(this.repository)
      : super(const SessionsState(isLoading: true, sessions: [])) {
    _init();
  }

  Future<void> _init() async {
    await repository.loadFromStorage();
    _sub = repository.watchSessions().listen(
      (items) => emit(state.copyWith(isLoading: false, sessions: items)),
      onError: (e, __) => emit(
        state.copyWith(isLoading: false, error: e.toString()),
      ),
    );
  }

  Future<void> addSessions(List<ScheduleSession> sessions) {
    return repository.addSessions(sessions);
  }

  Future<void> addSession(ScheduleSession session) {
    return repository.addSession(session);
  }

  Future<void> updateSession(ScheduleSession session) {
    return repository.updateSession(session);
  }

  Future<void> updateSessions(List<ScheduleSession> sessions) {
    return repository.updateSessions(sessions);
  }

  Future<void> deleteSession(int id) {
    return repository.deleteSession(id);
  }

  Future<void> deleteUpcomingSessionsForClient(String clientId) {
    return repository.deleteUpcomingSessionsForClient(clientId);
  }

  Future<void> restoreDeletedUpcomingSessionsForClient(String clientId) {
    return repository.restoreDeletedUpcomingSessionsForClient(clientId);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
