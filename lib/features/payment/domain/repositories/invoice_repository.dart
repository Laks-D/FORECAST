import '../entities/invoice.dart';

abstract class InvoiceRepository {
  /// Fetches invoices for a specific tutor.
  Stream<List<Invoice>> watchForTutor(String tutorUid);

  /// Fetches invoices for a specific client of a tutor.
  Stream<List<Invoice>> watchForClient(String tutorUid, String clientId);

  /// Adds a new invoice.
  Future<void> addInvoice(Invoice invoice);

  /// Updates an existing invoice (e.g., adding a pdfUrl).
  Future<void> updateInvoice(Invoice invoice);

  /// Deletes an invoice.
  Future<void> deleteInvoice(String tutorUid, String invoiceId);
}
