import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/firebase/firestore_db.dart';
import 'student_onboarding_event.dart';
import 'student_onboarding_state.dart';

class StudentOnboardingBloc
    extends Bloc<StudentOnboardingEvent, StudentOnboardingState> {
  StudentOnboardingBloc() : super(const StudentOnboardingState()) {
    on<SubmitStudentFormEvent>(_onSubmitStudentForm);
    on<ResetOnboardingEvent>(_onReset);
  }

  Future<void> _onSubmitStudentForm(
    SubmitStudentFormEvent event,
    Emitter<StudentOnboardingState> emit,
  ) async {
    emit(state.copyWith(status: StudentOnboardingStatus.loading));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Write to Firestore: users/{orgId}/students/{newDocId}
      // Note: orgId in this context holds the tutorId — organizations are removed.
      await firestoreDb
          .collection('users')
          .doc(event.orgId)
          .collection('students')
          .add({
        'tutorId': event.orgId,
        'fullName': event.fullName,
        'phone': event.phoneNumber,
        'profession': event.profession,
        'enrolledBy': uid,
        'status': 'enrolled',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      emit(
        state.copyWith(
          status: StudentOnboardingStatus.success,
          studentName: event.fullName,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentOnboardingStatus.failure,
          errorMessage: 'Failed to join the class: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onReset(
    ResetOnboardingEvent event,
    Emitter<StudentOnboardingState> emit,
  ) async {
    emit(const StudentOnboardingState());
  }
}
