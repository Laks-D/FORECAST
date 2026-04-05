import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../../domain/usecases/get_clients_usecase.dart';
import '../../domain/usecases/add_client_note_usecase.dart';
import '../../domain/usecases/add_client_payment_usecase.dart';
import '../../domain/usecases/add_client_status_usecase.dart';
import '../../domain/usecases/create_client_usecase.dart';
import '../../domain/usecases/update_client_details_usecase.dart';
import '../../domain/usecases/clear_payment_status_usecase.dart';
import '../../domain/usecases/reschedule_payment_usecase.dart';
import '../../domain/usecases/mark_paid_fully_usecase.dart';
import '../../domain/usecases/revert_paid_fully_usecase.dart';

import 'client_event.dart';
import 'client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final ClientRepository repository;
  final GetClientsUseCase getClientsUseCase;
  final AddClientNoteUseCase addClientNoteUseCase;
  final AddClientPaymentUseCase addClientPaymentUseCase;
  final AddClientStatusUseCase addClientStatusUseCase;
  final CreateClientUseCase createClientUseCase;
  final UpdateClientDetailsUseCase updateClientDetailsUseCase;
  final ClearPaymentStatusUseCase clearPaymentStatusUseCase;
  final ReschedulePaymentUseCase reschedulePaymentUseCase;
  final MarkPaidFullyUseCase markPaidFullyUseCase;
  final RevertPaidFullyUseCase revertPaidFullyUseCase;

  List<Client> _allEntities = [];

  Timer? _persistDebounce;
  Future<void> _persistChain = Future.value();

  ClientBloc(
    this.repository,
    this.getClientsUseCase,
    this.addClientNoteUseCase,
    this.addClientPaymentUseCase,
    this.addClientStatusUseCase,
    this.createClientUseCase,
    this.updateClientDetailsUseCase,
    this.clearPaymentStatusUseCase,
    this.reschedulePaymentUseCase,
    this.markPaidFullyUseCase,
    this.revertPaidFullyUseCase,
  ) : super(ClientLoading()) {
    on<LoadClients>(_onLoad);
    on<SearchClients>(_onSearch);
    on<AddNoteToClient>(_onAddNote);
    on<AddPaymentToClient>(_onAddPayment);
    on<UpdateClientStatus>(_onUpdateStatus);
    on<UpdateClientDetails>(_onUpdateDetails);
    on<CreateClient>(_onCreateClient);
    on<ClearPaymentStatusForDate>(_onClearPaymentStatus);
    on<RescheduleClientPayment>(_onReschedulePayment);
    on<MarkClientPaidFully>(_onMarkPaidFully);
    on<RevertClientPaidFully>(_onRevertPaidFully);
    on<DeleteClient>(_onDeleteClient);
    on<RestoreClient>(_onRestoreClient);
  }

  @override
  Future<void> close() {
    _persistDebounce?.cancel();
    return super.close();
  }

  /* ================= LOAD ================= */

  Future<void> _onLoad(
    LoadClients event,
    Emitter<ClientState> emit,
  ) async {
    await repository.loadFromStorage();
    _allEntities = getClientsUseCase.execute();
    emit(ClientLoaded(_allEntities));
  }

  /* ================= SEARCH ================= */

  void _onSearch(
    SearchClients event,
    Emitter<ClientState> emit,
  ) {
    final q = event.query.trim().toLowerCase();
    if (q.isEmpty) {
      emit(ClientLoaded(_allEntities));
      return;
    }

    // Build a set of clientIds whose sessions match the query by courseName.
    final Set<String> sessionMatchIds = {};
    for (final s in event.sessions) {
      final courseName = (s.courseName as String?)?.toLowerCase() ?? '';
      if (courseName.contains(q)) {
        sessionMatchIds.add(s.clientId as String);
      }
    }

    final filtered = _allEntities.where((e) {
      final name = e.name.toLowerCase();
      final contact = e.primaryContact.toLowerCase();
      final status = e.status.toLowerCase();
      return name.contains(q) ||
          contact.contains(q) ||
          status.contains(q) ||
          sessionMatchIds.contains(e.id);
    }).toList(growable: false);

    emit(ClientLoaded(filtered));
  }

  /* ================= ADD NOTE ================= */

  void _onAddNote(
    AddNoteToClient event,
    Emitter<ClientState> emit,
  ) {
    addClientNoteUseCase.execute(
      entityId: event.entityId,
      note: event.note,
      createdAt: event.createdAt,
    );

    _reload(emit);
  }

  /* ================= ADD PAYMENT ================= */

  void _onAddPayment(
    AddPaymentToClient event,
    Emitter<ClientState> emit,
  ) {
    addClientPaymentUseCase.execute(
      entityId: event.entityId,
      amount: event.amount,
      note: event.note,
      scheduledAt: event.scheduledAt,
    );

    _reload(emit);
  }

  /* ================= UPDATE STATUS ================= */

  void _onUpdateStatus(
    UpdateClientStatus event,
    Emitter<ClientState> emit,
  ) {
    addClientStatusUseCase.execute(
      entityId: event.entityId,
      status: event.status,
      createdAt: event.createdAt,
      refId: event.refId,
    );

    _reload(emit);
  }

  /* ================= UPDATE DETAILS ================= */

  void _onUpdateDetails(
    UpdateClientDetails event,
    Emitter<ClientState> emit,
  ) {
    final client = _allEntities.cast<Client?>().firstWhere(
          (e) => e?.id == event.entityId,
          orElse: () => null,
        );

    if (client != null) {
      updateClientDetailsUseCase.execute(
        entityId: event.entityId,
        name: event.name ?? client.name,
        primaryContact: event.primaryContact ?? client.primaryContact,
        middleName: event.middleName ?? client.middleName,
        countryCode: event.countryCode ?? client.countryCode,
        email: event.email ?? client.email,
        gender: event.gender ?? client.gender,
        dateOfBirth: event.dateOfBirth ?? client.dateOfBirth,
        address: event.address ?? client.address,
        currency: event.currency ?? client.currency,
      );

      _reload(emit);
    }
  }

  /* ================= ADD CLIENT ================= */

  void _onCreateClient(
    CreateClient event,
    Emitter<ClientState> emit,
  ) {
    createClientUseCase.execute(
      name: event.name,
      primaryContact: event.primaryContact,
      middleName: event.middleName,
      countryCode: event.countryCode,
      email: event.email,
      gender: event.gender,
      dateOfBirth: event.dateOfBirth,
      address: event.address,
    );

    _reload(emit);
  }

  /* ================= CLEAR PAYMENT STATUS ================= */

  void _onClearPaymentStatus(
    ClearPaymentStatusForDate event,
    Emitter<ClientState> emit,
  ) {
    clearPaymentStatusUseCase.execute(
      entityId: event.entityId,
      date: event.date,
      paymentId: event.paymentId,
    );

    _reload(emit);
  }

  /* ================= RESCHEDULE PAYMENT ================= */

  void _onReschedulePayment(
    RescheduleClientPayment event,
    Emitter<ClientState> emit,
  ) {
    reschedulePaymentUseCase.execute(
      entityId: event.entityId,
      paymentId: event.paymentId,
      oldDate: event.oldDate,
      newDate: event.newDate,
    );

    _reload(emit);
  }

  /* ================= MARK PAID FULLY ================= */

  void _onMarkPaidFully(
    MarkClientPaidFully event,
    Emitter<ClientState> emit,
  ) {
    markPaidFullyUseCase.execute(
      entityId: event.entityId,
      fromDate: event.fromDate,
    );

    _reload(emit);
  }

  /* ================= REVERT PAID FULLY ================= */

  void _onRevertPaidFully(
    RevertClientPaidFully event,
    Emitter<ClientState> emit,
  ) {
    revertPaidFullyUseCase.execute(entityId: event.entityId);
    _reload(emit);
  }

  /* ================= DELETE/RESTORE ================= */

  void _onDeleteClient(
    DeleteClient event,
    Emitter<ClientState> emit,
  ) {
    repository.deleteClient(entityId: event.entityId);
    _reload(emit);
  }

  void _onRestoreClient(
    RestoreClient event,
    Emitter<ClientState> emit,
  ) {
    repository.restoreClient(entityId: event.entityId);
    _reload(emit);
  }

  /* ================= RELOAD ================= */

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 250), () {
      // Serialize persists so SharedPreferences + Firestore mirror always end up
      // with the latest snapshot (prevents out-of-order overwrites).
      _persistChain = _persistChain.then((_) => repository.persist());
    });
  }

  void _reload(Emitter<ClientState> emit) {
    _allEntities = getClientsUseCase.execute();
    emit(ClientLoaded(_allEntities));
    _schedulePersist();
  }
}