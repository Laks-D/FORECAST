import 'package:get_it/get_it.dart';

/* ================= CLIENT – DATA ================= */
import '../../features/client/data/datasources/client_local_datasource.dart';
import '../../features/client/data/repositories/client_repository_impl.dart';

/* ================= CLIENT – DOMAIN ================= */
import '../../features/client/domain/repositories/client_repository.dart';
import '../../features/client/domain/usecases/get_clients_usecase.dart';
import '../../features/client/domain/usecases/add_client_note_usecase.dart';
import '../../features/client/domain/usecases/add_client_payment_usecase.dart';
import '../../features/client/domain/usecases/add_client_status_usecase.dart';
import '../../features/client/domain/usecases/create_client_usecase.dart';
import '../../features/client/domain/usecases/update_client_details_usecase.dart';
import '../../features/client/domain/usecases/clear_payment_status_usecase.dart';
import '../../features/client/domain/usecases/reschedule_payment_usecase.dart';
import '../../features/client/domain/usecases/mark_paid_fully_usecase.dart';
import '../../features/client/domain/usecases/revert_paid_fully_usecase.dart';

/* ================= CLIENT – PRESENTATION ================= */
import '../../features/client/presentation/bloc/client_bloc.dart';

/* ================= CALENDAR/SCHEDULE – DATA ================= */
import '../../features/calendar/data/datasources/schedule_local_datasource.dart';
import '../../features/calendar/data/repositories/schedule_repository_impl.dart';

/* ================= CALENDAR/SCHEDULE – DOMAIN ================= */
import '../../features/calendar/domain/repositories/schedule_repository.dart';

/* ================= CALENDAR/SCHEDULE – PRESENTATION ================= */
import '../../features/calendar/bloc/sessions_cubit.dart';

/* ================= NAVIGATION – PRESENTATION ================= */
import '../../features/navigation/bloc/nav_modules_cubit.dart';

final GetIt sl = GetIt.instance;

bool _isSetup = false;

Future<void> setupServiceLocator() async {
  if (_isSetup) return;

  /* ================= CLIENT – DATA ================= */

  // Local in-memory datasource (single instance)
  sl.registerLazySingleton<ClientLocalDataSource>(
    () => ClientLocalDataSource(),
  );

  // Repository
  sl.registerLazySingleton<ClientRepository>(
    () => ClientRepositoryImpl(sl()),
  );

  /* ================= CLIENT – DOMAIN ================= */

  sl.registerLazySingleton<GetClientsUseCase>(
    () => GetClientsUseCase(sl()),
  );

  sl.registerLazySingleton<AddClientNoteUseCase>(
    () => AddClientNoteUseCase(sl()),
  );

  sl.registerLazySingleton<CreateClientUseCase>(
    () => CreateClientUseCase(sl()),
  );

  sl.registerLazySingleton<AddClientPaymentUseCase>(
    () => AddClientPaymentUseCase(sl()),
  );

  sl.registerLazySingleton<AddClientStatusUseCase>(
    () => AddClientStatusUseCase(sl()),
  );

  sl.registerLazySingleton<UpdateClientDetailsUseCase>(
    () => UpdateClientDetailsUseCase(sl()),
  );

  sl.registerLazySingleton<ClearPaymentStatusUseCase>(
    () => ClearPaymentStatusUseCase(sl()),
  );

  sl.registerLazySingleton<ReschedulePaymentUseCase>(
    () => ReschedulePaymentUseCase(sl()),
  );

  sl.registerLazySingleton<MarkPaidFullyUseCase>(
    () => MarkPaidFullyUseCase(sl()),
  );

  sl.registerLazySingleton<RevertPaidFullyUseCase>(
    () => RevertPaidFullyUseCase(sl()),
  );

  sl.registerFactory<ClientBloc>(
    () => ClientBloc(
      sl<ClientRepository>(),
      sl<GetClientsUseCase>(),
      sl<AddClientNoteUseCase>(),
      sl<AddClientPaymentUseCase>(),
      sl<AddClientStatusUseCase>(),
      sl<CreateClientUseCase>(),
      sl<UpdateClientDetailsUseCase>(),
      sl<ClearPaymentStatusUseCase>(),
      sl<ReschedulePaymentUseCase>(),
      sl<MarkPaidFullyUseCase>(),
      sl<RevertPaidFullyUseCase>(),
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
    () => SessionsCubit(sl<ScheduleRepository>()),
  );

  /* ================= NAVIGATION – PRESENTATION ================= */

  // Single shared instance across the whole app to avoid Provider scope issues
  // when opening routes / bottom sheets.
  sl.registerLazySingleton<NavModulesCubit>(
    () => NavModulesCubit(),
  );

  _isSetup = true;
}