import 'package:equatable/equatable.dart';

abstract class StudentOnboardingEvent extends Equatable {
  const StudentOnboardingEvent();

  @override
  List<Object?> get props => [];
}

class SubmitStudentFormEvent extends StudentOnboardingEvent {
  final String orgId;
  final String fullName;
  final String phoneNumber;
  final String profession;

  const SubmitStudentFormEvent({
    required this.orgId,
    required this.fullName,
    required this.phoneNumber,
    required this.profession,
  });

  @override
  List<Object?> get props => [orgId, fullName, phoneNumber, profession];
}

class ResetOnboardingEvent extends StudentOnboardingEvent {
  const ResetOnboardingEvent();
}
