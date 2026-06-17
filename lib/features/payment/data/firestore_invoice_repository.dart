import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/invoice.dart';
import '../domain/repositories/invoice_repository.dart';

class FirestoreInvoiceRepository implements InvoiceRepository {
  final FirebaseFirestore firestore;

  FirestoreInvoiceRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> _collection(String tutorUid) {
    return firestore.collection('users').doc(tutorUid).collection('invoices');
  }

  Invoice _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Invoice(
      id: doc.id,
      tutorId: data['tutorId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? '',
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pdfUrl: data['pdfUrl'] as String?,
    );
  }

  Map<String, dynamic> _toFirestore(Invoice invoice) {
    return {
      'tutorId': invoice.tutorId,
      'clientId': invoice.clientId,
      'items': invoice.items.map((e) => e.toJson()).toList(),
      'total': invoice.total,
      'currency': invoice.currency,
      'issuedAt': Timestamp.fromDate(invoice.issuedAt),
      if (invoice.pdfUrl != null) 'pdfUrl': invoice.pdfUrl,
    };
  }

  @override
  Stream<List<Invoice>> watchForTutor(String tutorUid) {
    return _collection(tutorUid)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => _fromFirestore(doc)).toList());
  }

  @override
  Stream<List<Invoice>> watchForClient(String tutorUid, String clientId) {
    return _collection(tutorUid)
        .where('clientId', isEqualTo: clientId)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => _fromFirestore(doc)).toList());
  }

  @override
  Future<void> addInvoice(Invoice invoice) async {
    await _collection(invoice.tutorId)
        .doc(invoice.id)
        .set(_toFirestore(invoice));
  }

  @override
  Future<void> updateInvoice(Invoice invoice) async {
    await _collection(invoice.tutorId)
        .doc(invoice.id)
        .update(_toFirestore(invoice));
  }

  @override
  Future<void> deleteInvoice(String tutorUid, String invoiceId) async {
    await _collection(tutorUid).doc(invoiceId).delete();
  }
}
