import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  final String paymentId;
  final String description;
  final double amount;

  const InvoiceItem({
    required this.paymentId,
    required this.description,
    required this.amount,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      paymentId: json['paymentId'] as String? ?? '',
      description: json['desc'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'desc': description,
      'amount': amount,
    };
  }

  @override
  List<Object?> get props => [paymentId, description, amount];
}

class Invoice extends Equatable {
  final String id;
  final String tutorId;
  final String clientId;
  final List<InvoiceItem> items;
  final double total;
  final String currency;
  final DateTime issuedAt;
  final String? pdfUrl;

  const Invoice({
    required this.id,
    required this.tutorId,
    required this.clientId,
    required this.items,
    required this.total,
    required this.currency,
    required this.issuedAt,
    this.pdfUrl,
  });

  @override
  List<Object?> get props => [
        id,
        tutorId,
        clientId,
        items,
        total,
        currency,
        issuedAt,
        pdfUrl,
      ];
}
