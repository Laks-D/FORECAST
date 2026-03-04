import '../repositories/client_repository.dart';

class MergePaymentsUseCase {
  final ClientRepository repository;

  const MergePaymentsUseCase(this.repository);

  void execute({
    required String entityId,
    required String sourcePaymentId,
    required DateTime sourceDate,
    required String targetPaymentId,
    required DateTime targetDate,
    required double mergedAmount,
    String? mergedNote,
  }) {
    repository.mergePayments(
      entityId: entityId,
      sourcePaymentId: sourcePaymentId,
      sourceDate: sourceDate,
      targetPaymentId: targetPaymentId,
      targetDate: targetDate,
      mergedAmount: mergedAmount,
      mergedNote: mergedNote,
    );
  }
}
