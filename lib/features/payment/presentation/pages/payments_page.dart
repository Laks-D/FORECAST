import 'package:flutter/material.dart';

import 'payments_queue_page.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key, this.embedInDashboard = false});

  final bool embedInDashboard;

  @override
  Widget build(BuildContext context) {
    return PaymentsQueuePage(embedInDashboard: embedInDashboard);
  }
}