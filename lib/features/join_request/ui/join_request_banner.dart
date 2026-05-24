import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../bloc/join_request_listener_cubit.dart';
import '../join_request_model.dart';
import '../join_request_service.dart';

/// Admin-side widget that wraps any child and shows a floating bottom sheet
/// whenever a new client join request arrives in real time.
///
/// Place this as a wrapper inside the dashboard body.
class JoinRequestBanner extends StatefulWidget {
  const JoinRequestBanner({super.key, required this.child});

  final Widget child;

  @override
  State<JoinRequestBanner> createState() => _JoinRequestBannerState();
}

class _JoinRequestBannerState extends State<JoinRequestBanner> {
  /// Track which request IDs have already been shown so we don't re-show
  /// on every BLoC rebuild.
  final Set<String> _shown = {};
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<JoinRequestListenerCubit, List<JoinRequestModel>>(
      listener: (context, requests) {
        for (final req in requests) {
          if (_shown.contains(req.id)) continue;
          if (_sheetOpen) continue;
          _shown.add(req.id);
          _showRequestSheet(context, req);
          break; // show one at a time; next fires when sheet closes
        }
      },
      child: widget.child,
    );
  }

  Future<void> _showRequestSheet(
    BuildContext parentCtx,
    JoinRequestModel req,
  ) async {
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: parentCtx,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _JoinRequestSheet(
        request: req,
        onAccept: () async {
          await JoinRequestService.resolve(req.id, 'accepted');
          if (!parentCtx.mounted) return;
          // Add student to the tutor's local client list so they appear immediately.
          final phone = req.clientPhone.trim();
          parentCtx.read<ClientBloc>().add(CreateClient(
            name: req.clientName.isNotEmpty ? req.clientName : 'Student',
            primaryContact: phone.isNotEmpty ? phone : '0000000000',
          ));
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            SnackBar(
              content: Text('✓ ${req.clientName} accepted'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onReject: () async {
          await JoinRequestService.resolve(req.id, 'rejected');
          if (!parentCtx.mounted) return;
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            SnackBar(
              content: Text('${req.clientName} request declined'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
    _sheetOpen = false;

    // After one sheet closes, check if more pending requests arrived while it was open.
    if (!mounted) return;
    final remaining = context.read<JoinRequestListenerCubit>().state;
    for (final pending in remaining) {
      if (!_shown.contains(pending.id)) {
        _shown.add(pending.id);
        _showRequestSheet(context, pending);
        break;
      }
    }
  }
}

// ── BOTTOM SHEET UI ───────────────────────────────────────────────────────────

class _JoinRequestSheet extends StatelessWidget {
  const _JoinRequestSheet({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final JoinRequestModel request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'JOIN REQUEST',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: scheme.onSurface.withOpacity(0.4)),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Client avatar + info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
                      child: Text(
                        request.clientName.isNotEmpty
                            ? request.clientName.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.clientName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.clientPhone,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'wants to join your class',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        color: const Color(0xFFEF4444),
                        icon: Icons.close_rounded,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await onReject();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Accept',
                        color: const Color(0xFF22C55E),
                        icon: Icons.check_rounded,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await onAccept();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
