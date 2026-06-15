import re
import sys

with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'r') as f:
    content = f.read()

import_str = "import 'package:flutter_bloc/flutter_bloc.dart';\nimport '../../domain/entities/client_event.dart';\nimport '../../domain/entities/payment.dart';\nimport '../../../client/presentation/bloc/client_bloc.dart';\n"
content = import_str + content

old_section = """                    row(
                      'Last Activity',
                      Text(
                        _formatDate(widget.entity.lastActivityAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: chrome.textColor),
                      ),
                    ),
                    row(
                      'Total Payments',
                      Text(
                        _money(widget.entity.outstandingAmount, currency),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),"""

new_section = """                    StreamBuilder<List<ClientEvent>>(
                      stream: context.read<ClientBloc>().clientEventRepository.watchForClient(widget.entity.id),
                      builder: (context, eventSnap) {
                        final lastActivityAt = eventSnap.data?.isNotEmpty == true ? eventSnap.data!.first.createdAt : null;
                        return row(
                          'Last Activity',
                          Text(
                            _formatDate(lastActivityAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: chrome.textColor),
                          ),
                        );
                      }
                    ),
                    StreamBuilder<List<Payment>>(
                      stream: context.read<ClientBloc>().paymentRepository.watchForClient(widget.entity.id),
                      builder: (context, paySnap) {
                        final payments = paySnap.data ?? [];
                        final now = DateTime.now();
                        double outstanding = 0;
                        for (final p in payments) {
                           if (p.status != PaymentStatus.paid && p.dueDate.isBefore(now)) {
                              outstanding += p.amount;
                           }
                        }
                        return row(
                          'Total Payments',
                          Text(
                            _money(outstanding, currency),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: chrome.textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        );
                      }
                    ),"""

content = content.replace(old_section, new_section)

with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'w') as f:
    f.write(content)

