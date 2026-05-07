import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/supabase_service.dart';
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
      await SupabaseService.instance.addStudent(
        event.orgId,
        event.fullName,
        event.phoneNumber,
        event.profession,
      );

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
