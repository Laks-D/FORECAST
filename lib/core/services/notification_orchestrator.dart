import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../features/calendar/bloc/sessions_cubit.dart';
import '../../features/client/domain/entities/client.dart';
import '../../features/client/presentation/bloc/client_bloc.dart';
import '../../features/client/presentation/bloc/client_state.dart';
import '../../features/calendar/domain/entities/schedule_session.dart';
import '../services/notification_service.dart';

/// Wires together [SessionsCubit] + [ClientBloc] → [NotificationService].
///
/// Usage (in main.dart after runApp):
///   NotificationOrchestrator.instance.attach(
///     sessionsCubit: sl<SessionsCubit>(),
///     clientBloc: sl<ClientBloc>(),
///   );
///
/// The orchestrator listens to both Blocs. When either emits new data it
/// debounces and calls [NotificationService.scheduleAll], passing the user's
/// current preferences.
///
/// This mirrors exactly how NI's DashboardBloc._scheduleNotifications works,
/// but without coupling it to the Dashboard, so it works even if the user is
/// on the Calendar or Settings page.
class NotificationOrchestrator {
  NotificationOrchestrator._();
  static final NotificationOrchestrator instance = NotificationOrchestrator._();

  StreamSubscription<dynamic>? _sessionsSub;
  StreamSubscription<dynamic>? _clientSub;
  StreamSubscription<User?>? _authSub;

  List<ScheduleSession> _sessions = [];
  List<Client> _clients = [];

  // ─── User preferences (updated by NotificationCubit via attach) ───
  bool sessionRemindersEnabled = true;
  int sessionLeadMinutes = 5;
  bool paymentRemindersEnabled = true;
  int paymentHour = 8;
  int paymentMinute = 0;
  int paymentDaysBefore = 0;
  bool paymentOverdueDaily = true;

  void attach({
    required SessionsCubit sessionsCubit,
    required ClientBloc clientBloc,
  }) {
    _sessionsSub?.cancel();
    _clientSub?.cancel();
    _authSub?.cancel();

    // Listen to sessions.
    _sessionsSub = sessionsCubit.stream.listen((state) {
      if (state.isLoading) return;
      _sessions = state.sessions;
      _trigger();
    });

    // Listen to clients.
    _clientSub = clientBloc.stream.listen((state) {
      if (state is ClientLoaded) {
        _clients = state.entities;
        _trigger();
      } else if (state is ClientLoading) {
        // Don't reschedule while loading.
      }
    });

    // Clear alarms on sign-out.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _sessions = [];
        _clients = [];
        NotificationService.instance.cancelAll();
      }
    });
  }

  void detach() {
    _sessionsSub?.cancel();
    _clientSub?.cancel();
    _authSub?.cancel();
    _sessionsSub = null;
    _clientSub = null;
    _authSub = null;
  }

  void _trigger() {
    // Only schedule for tutors (not students — they get FCM from backend).
    NotificationService.instance.scheduleAll(
      clients: _clients,
      sessions: _sessions,
      sessionRemindersEnabled: sessionRemindersEnabled,
      sessionLeadMinutes: sessionLeadMinutes,
      paymentRemindersEnabled: paymentRemindersEnabled,
      paymentHour: paymentHour,
      paymentMinute: paymentMinute,
      paymentDaysBefore: paymentDaysBefore,
      paymentOverdueDaily: paymentOverdueDaily,
    );
  }

  /// Call this when the user updates their notification preferences.
  void updatePreferences({
    bool? sessionRemindersEnabled,
    int? sessionLeadMinutes,
    bool? paymentRemindersEnabled,
    int? paymentHour,
    int? paymentMinute,
    int? paymentDaysBefore,
    bool? paymentOverdueDaily,
  }) {
    if (sessionRemindersEnabled != null) {
      this.sessionRemindersEnabled = sessionRemindersEnabled;
    }
    if (sessionLeadMinutes != null) {
      this.sessionLeadMinutes = sessionLeadMinutes;
    }
    if (paymentRemindersEnabled != null) {
      this.paymentRemindersEnabled = paymentRemindersEnabled;
    }
    if (paymentHour != null) this.paymentHour = paymentHour;
    if (paymentMinute != null) this.paymentMinute = paymentMinute;
    if (paymentDaysBefore != null) this.paymentDaysBefore = paymentDaysBefore;
    if (paymentOverdueDaily != null) this.paymentOverdueDaily = paymentOverdueDaily;
    // Retrigger reschedule with new prefs.
    _trigger();
  }
}
