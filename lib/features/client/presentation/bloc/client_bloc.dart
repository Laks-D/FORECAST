import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/app/app_mode.dart';
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../../../payment/domain/repositories/payment_repository.dart';
import '../../../payment/domain/entities/payment.dart';
import '../../data/client_event_repository.dart';
import '../../domain/entities/client_event.dart' as domain;

import 'client_event.dart';
import 'client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final ClientRepository repository;
  final PaymentRepository paymentRepository;
  final ClientEventRepository clientEventRepository;

  List<Client> _allEntities = [];
  StreamSubscription? _clientsSub;

  final _uuid = const Uuid();

  ClientBloc({
    required this.repository,
    required this.paymentRepository,
    required this.clientEventRepository,
  }) : super(ClientLoading()) {
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
    on<PermanentlyDeleteClient>(_onPermanentlyDeleteClient);
    on<MarkSinglePaymentPaid>(_onMarkSinglePaymentPaid);
  }

  @override
  Future<void> close() {
    _clientsSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(LoadClients event, Emitter<ClientState> emit) async {
    await _clientsSub?.cancel();
    emit(ClientLoading());
    await repository.loadFromStorage();

    await emit.forEach<List<Client>>(
      repository.watchClients(),
      onData: (clients) {
        _allEntities = clients;
        
        // Client app: show only the signed-in client's own record.
        if (AppModeConfig.isClient) {
          final uid = _currentUserUidSafe();
          final email = _currentUserEmailSafe();
          final phone = _currentUserPhoneSafe();
          if (uid != null && uid.isNotEmpty) {
            final filtered = _allEntities
                .where((c) => (c.firebaseUid ?? '').trim() == uid)
                .toList(growable: false);

            if (filtered.isNotEmpty) {
              _allEntities = filtered;
            } else {
              // Auto-patch matching logic would go here if needed
              _allEntities = const <Client>[];
            }
          } else {
            _allEntities = const <Client>[];
          }
        }
        
        return ClientLoaded(_allEntities);
      },
      onError: (_, __) => ClientLoaded(_allEntities),
    );
  }

  String? _currentUserUidSafe() => FirebaseAuth.instance.currentUser?.uid;
  String? _currentUserEmailSafe() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return null;
    final s = email.trim().toLowerCase();
    return s.isEmpty ? null : s;
  }
  String? _currentUserPhoneSafe() {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) return null;
    final s = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    return s.isEmpty ? null : s;
  }

  void _onSearch(SearchClients event, Emitter<ClientState> emit) {
    final q = event.query.trim().toLowerCase();
    if (q.isEmpty) {
      emit(ClientLoaded(_allEntities));
      return;
    }

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

  Future<void> _onAddNote(AddNoteToClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    final client = _allEntities.cast<Client?>().firstWhere((e) => e?.id == event.entityId, orElse: () => null);
    if (client == null) return;
    
    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: domain.ClientEventType.note,
      note: event.note,
      createdAt: event.createdAt ?? DateTime.now(),
    ));
  }

  Future<void> _onAddPayment(AddPaymentToClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    final client = _allEntities.cast<Client?>().firstWhere((e) => e?.id == event.entityId, orElse: () => null);
    if (client == null) return;

    await paymentRepository.add(Payment(
      paymentId: _uuid.v4(),
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      clientId: event.entityId,
      firebaseUid: client.firebaseUid,
      amount: event.amount,
      currency: client.currency ?? '₹',
      status: PaymentStatus.unpaid,
      dueDate: event.scheduledAt ?? DateTime.now(),
      note: event.note,
    ));
  }

  Future<void> _onUpdateStatus(UpdateClientStatus event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    final client = _allEntities.cast<Client?>().firstWhere((e) => e?.id == event.entityId, orElse: () => null);
    if (client == null) return;

    await repository.updateClient(Client(
      id: client.id,
      firebaseUid: client.firebaseUid,
      name: client.name,
      middleName: client.middleName,
      primaryContact: client.primaryContact,
      countryCode: client.countryCode,
      email: client.email,
      gender: client.gender,
      dateOfBirth: client.dateOfBirth,
      address: client.address,
      currency: client.currency,
      status: event.status,
      pinned: client.pinned,
    ));

    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: domain.ClientEventType.statusChanged,
      status: event.status,
      createdAt: event.createdAt ?? DateTime.now(),
    ));
  }

  Future<void> _onUpdateDetails(UpdateClientDetails event, Emitter<ClientState> emit) async {
    final isClientSelfEdit = AppModeConfig.isClient &&
        _allEntities.isNotEmpty &&
        _allEntities.first.id == event.entityId;

    if (AppModeConfig.isClient && !isClientSelfEdit) return;

    final client = _allEntities.cast<Client?>().firstWhere(
          (e) => e?.id == event.entityId,
          orElse: () => null,
        );

    if (client != null) {
      await repository.updateClient(Client(
        id: client.id,
        name: event.name ?? client.name,
        primaryContact: event.primaryContact ?? client.primaryContact,
        firebaseUid: AppModeConfig.isClient ? _currentUserUidSafe() : (event.firebaseUid ?? client.firebaseUid),
        middleName: event.middleName ?? client.middleName,
        countryCode: event.countryCode ?? client.countryCode,
        email: AppModeConfig.isClient ? client.email : (event.email ?? client.email),
        gender: event.gender ?? client.gender,
        dateOfBirth: event.dateOfBirth ?? client.dateOfBirth,
        address: event.address ?? client.address,
        currency: event.currency ?? client.currency,
        status: client.status,
        pinned: client.pinned,
      ));
    }
  }

  Future<void> _onCreateClient(CreateClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    
    final clientId = _uuid.v4();
    final client = Client(
      id: clientId,
      firebaseUid: event.firebaseUid,
      name: event.name,
      middleName: event.middleName,
      primaryContact: event.primaryContact,
      countryCode: event.countryCode,
      email: event.email,
      gender: event.gender,
      dateOfBirth: event.dateOfBirth,
      address: event.address,
      status: 'Active',
      pinned: false,
    );
    await repository.addClient(client);

    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: clientId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: event.firebaseUid,
      type: domain.ClientEventType.profileCreated,
      createdAt: DateTime.now(),
    ));
    
    if (event.referredBy != null) {
      await clientEventRepository.add(domain.ClientEvent(
        eventId: _uuid.v4(),
        clientId: clientId,
        tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
        firebaseUid: event.firebaseUid,
        type: domain.ClientEventType.note,
        note: 'Referred by: ${event.referredBy}',
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> _onClearPaymentStatus(ClearPaymentStatusForDate event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    if (event.paymentId != null) {
       await paymentRepository.setStatus(event.paymentId!, PaymentStatus.unpaid);
    }
  }

  Future<void> _onReschedulePayment(RescheduleClientPayment event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    // Just find the payment and update its due date. We don't have the full payment object here.
    // So we'd need to fetch it or update specific fields.
    // Assuming we have to fetch the payment:
    final payments = await paymentRepository.getForClient(event.entityId);
    final payment = payments.cast<Payment?>().firstWhere((p) => p?.paymentId == event.paymentId, orElse: () => null);
    if (payment != null) {
      await paymentRepository.update(payment.copyWith(dueDate: event.newDate));
    }
  }

  Future<void> _onMarkPaidFully(MarkClientPaidFully event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    final payments = await paymentRepository.getForClient(event.entityId);
    for (final p in payments) {
      if (p.status == PaymentStatus.unpaid && !p.dueDate.isBefore(event.fromDate)) {
        await paymentRepository.markPaid(p.paymentId);
      }
    }
  }

  Future<void> _onRevertPaidFully(RevertClientPaidFully event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    final payments = await paymentRepository.getForClient(event.entityId);
    for (final p in payments) {
      if (p.status == PaymentStatus.paid) {
         // This is a naive revert, you'd usually have a better way to track this.
         await paymentRepository.setStatus(p.paymentId, PaymentStatus.unpaid);
      }
    }
  }

  Future<void> _onDeleteClient(DeleteClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    await repository.deleteClient(entityId: event.entityId);
  }

  Future<void> _onRestoreClient(RestoreClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    await repository.restoreClient(entityId: event.entityId);
  }

  Future<void> _onPermanentlyDeleteClient(PermanentlyDeleteClient event, Emitter<ClientState> emit) async {
    if (AppModeConfig.isClient) return;
    await repository.permanentlyDeleteClient(entityId: event.entityId);
  }

  /// Allows a student (client mode) to mark a single payment as paid.
  /// This intentionally bypasses the isClient guard — it only touches
  /// the payment status, not any client record.
  Future<void> _onMarkSinglePaymentPaid(MarkSinglePaymentPaid event, Emitter<ClientState> emit) async {
    await paymentRepository.markPaid(event.paymentId);
  }
}
