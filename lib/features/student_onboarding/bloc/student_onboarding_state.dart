import 'package:equatable/equatable.dart';

enum StudentOnboardingStatus {
  initial,
  loading,
  success,
  failure,
}

class StudentOnboardingState extends Equatable {
  final StudentOnboardingStatus status;
  final String? errorMessage;
  final String? studentName;

  const StudentOnboardingState({
    this.status = StudentOnboardingStatus.initial,
    this.errorMessage,
    this.studentName,
  });

  StudentOnboardingState copyWith({
    StudentOnboardingStatus? status,
    String? errorMessage,
    String? studentName,
  }) {
    return StudentOnboardingState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      studentName: studentName ?? this.studentName,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, studentName];
}
