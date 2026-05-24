import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../join_request_model.dart';
import '../join_request_service.dart';

/// Admin-side cubit that listens to the Firestore `join_requests` collection
/// for the admin's tutorId and emits a live list of pending requests.
///
/// Usage:
/// ```dart
/// context.read<JoinRequestListenerCubit>().startForAdmin(tutorUid);
/// ```
class JoinRequestListenerCubit extends Cubit<List<JoinRequestModel>> {
  JoinRequestListenerCubit() : super(const []);

  StreamSubscription<List<JoinRequestModel>>? _sub;

  /// Starts the Firestore listener for the given admin [tutorUid].
  /// Uses [tutorUid] directly — no organization lookup needed.
  Future<void> startForAdmin(String tutorUid) async {
    await _sub?.cancel();
    _sub = JoinRequestService.watchPendingForTutor(tutorUid).listen(
      (requests) {
        if (!isClosed) emit(requests);
      },
      onError: (_) {
        if (!isClosed) emit(const []);
      },
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
