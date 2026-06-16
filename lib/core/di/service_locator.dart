import '../../features/payment/domain/repositories/invoice_repository.dart';
import '../../features/payment/data/firestore_invoice_repository.dart';
import '../../features/client/domain/repositories/client_repository.dart';
import 'package:get_it/get_it.dart';

/* ================= CLIENT – PRESENTATION ================= */
import '../../features/client/presentation/bloc/client_bloc.dart';
import '../../features/client/data/firestore_client_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/* ================= CALENDAR/SCHEDULE – DATA ================= */
import '../../features/calendar/data/datasources/schedule_local_datasource.dart';
import '../../features/calendar/data/repositories/schedule_repository_impl.dart';

/* ================= CALENDAR/SCHEDULE – DOMAIN ================= */
import '../../features/calendar/domain/repositories/schedule_repository.dart';

/* ================= CALENDAR/SCHEDULE – PRESENTATION ================= */
import '../../features/calendar/bloc/sessions_cubit.dart';

/* ================= NAVIGATION – PRESENTATION ================= */
import '../../features/navigation/bloc/nav_modules_cubit.dart';

/* ================= SCHEMA MIGRATION – NEW REPOSITORIES ================= */
import '../../features/payment/domain/repositories/payment_repository.dart';
import '../../features/payment/data/firestore_payment_repository.dart';
import '../../features/client/data/client_event_repository.dart';
import '../../features/course/data/program_repository.dart';
import '../../features/calendar/data/recurrence_rule_repository.dart';
import '../../features/audit/audit_log_repository.dart';
import '../../features/auth/data/username_repository.dart';
import '../../features/notifications/data/fcm_token_repository.dart';
import '../../features/notifications/data/notification_record_repository.dart';

final GetIt sl = GetIt.instance;

bool _isSetup = false;

Future<void> setupServiceLocator() async {
  if (_isSetup) return;

  /* ================= CLIENT – DATA ================= */

  // Repository
  sl.registerLazySingleton<ClientRepository>(
    () => FirestoreClientRepository(
      firestore: FirebaseFirestore.instance,
    ),
  );

  /* ================= CLIENT – PRESENTATION ================= */

  sl.registerFactory<ClientBloc>(
    () => ClientBloc(
      repository: sl<ClientRepository>(),
      paymentRepository: sl<PaymentRepository>(),
      clientEventRepository: sl<ClientEventRepository>(),
    ),
  );

  /* ================= CALENDAR/SCHEDULE – DATA ================= */

  sl.registerLazySingleton<ScheduleLocalDataSource>(
    () => ScheduleLocalDataSource(),
  );

  sl.registerLazySingleton<ScheduleRepository>(
    () => ScheduleRepositoryImpl(sl()),
  );

  /* ================= CALENDAR/SCHEDULE – PRESENTATION ================= */

  // Single shared instance across the whole app to avoid Provider scope issues
  // when opening bottom sheets / routes.
  sl.registerLazySingleton<SessionsCubit>(
    () => SessionsCubit(sl<ScheduleRepository>(), recurrenceRepository: sl<RecurrenceRuleRepository>()),
  );

  /* ================= NAVIGATION – PRESENTATION ================= */

  // Single shared instance across the whole app to avoid Provider scope issues
  // when opening routes / bottom sheets.
  sl.registerLazySingleton<NavModulesCubit>(
    () => NavModulesCubit(),
  );

  /* ================= SCHEMA MIGRATION – NEW REPOSITORIES ================= */
  // Additive: registered for new read/dual-write paths. Existing features are
  // unaffected until they are explicitly switched over.
  sl.registerLazySingleton<PaymentRepository>(
    () => FirestorePaymentRepository(),
  );
  sl.registerLazySingleton<ClientEventRepository>(
    () => FirestoreClientEventRepository(),
  );
  sl.registerLazySingleton<ProgramRepository>(
    () => FirestoreProgramRepository(),
  );
  sl.registerLazySingleton<RecurrenceRuleRepository>(
    () => FirestoreRecurrenceRuleRepository(),
  );
  sl.registerLazySingleton<AuditLogRepository>(
    () => FirestoreAuditLogRepository(),
  );
  sl.registerLazySingleton<UsernameRepository>(
    () => FirestoreUsernameRepository(),
  );
  sl.registerLazySingleton<FcmTokenRepository>(
    () => FirestoreFcmTokenRepository(),
  );
  sl.registerLazySingleton<NotificationRecordRepository>(
    () => FirestoreNotificationRecordRepository(),
  );

  _isSetup = true;
}