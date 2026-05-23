import 'dart:async';

import 'package:flutter/material.dart';

import '../join_request_service.dart';

/// Client-side screen shown after submitting a join request.
///
/// Listens in real-time to the request's `status` field in Firestore.
/// - `pending`  → animated waiting state
/// - `accepted` → success screen
/// - `rejected` → rejection screen
/// - Timeout after [_kTimeoutSeconds] seconds if admin doesn't respond.
class JoinRequestWaitingPage extends StatefulWidget {
  const JoinRequestWaitingPage({
    super.key,
    required this.docId,
    required this.adminName,
  });

  final String docId;
  final String adminName;

  @override
  State<JoinRequestWaitingPage> createState() => _JoinRequestWaitingPageState();
}

class _JoinRequestWaitingPageState extends State<JoinRequestWaitingPage>
    with SingleTickerProviderStateMixin {
  static const _kTimeoutSeconds = 300; // 5 minutes

  late final AnimationController _pulseController;
  StreamSubscription<String>? _statusSub;
  String _status = 'pending';
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _statusSub = JoinRequestService.watchStatus(widget.docId).listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
    });

    _timeoutTimer = Timer(const Duration(seconds: _kTimeoutSeconds), () {
      if (!mounted) return;
      if (_status == 'pending') {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != 'pending' || _timedOut,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F14),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_timedOut) return _TimeoutView(onRetry: () => Navigator.of(context).pop());
    switch (_status) {
      case 'accepted':
        return _AcceptedView(adminName: widget.adminName);
      case 'rejected':
        return _RejectedView(onBack: () => Navigator.of(context).pop());
      default:
        return _WaitingView(
          adminName: widget.adminName,
          pulseController: _pulseController,
        );
    }
  }
}

// ── WAITING ──────────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.adminName,
    required this.pulseController,
  });

  final String adminName;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) {
                final scale = 0.85 + (0.15 * pulseController.value);
                final opacity = 0.4 + (0.6 * pulseController.value);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF).withOpacity(opacity * 0.18),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(opacity),
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 52,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              'Waiting for approval',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your request has been sent to $adminName.\nThey will accept or decline shortly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 40),
            const _PulsingDots(),
          ],
        ),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    Colors.white24,
                    const Color(0xFF6C63FF),
                    t,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── ACCEPTED ─────────────────────────────────────────────────────────────────

class _AcceptedView extends StatelessWidget {
  const _AcceptedView({required this.adminName});

  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withOpacity(0.12),
                border: Border.all(
                  color: const Color(0xFF22C55E),
                  width: 2.5,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 64,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "You're in! 🎉",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '$adminName has accepted your request.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text(
                  'Go to Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── REJECTED ─────────────────────────────────────────────────────────────────

class _RejectedView extends StatelessWidget {
  const _RejectedView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withOpacity(0.12),
                border: Border.all(
                  color: const Color(0xFFEF4444),
                  width: 2.5,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 64,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Request Declined',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'The tutor has declined your request to join.\nPlease try again or contact them directly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onBack,
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TIMEOUT ───────────────────────────────────────────────────────────────────

class _TimeoutView extends StatelessWidget {
  const _TimeoutView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_off_outlined, size: 72, color: Colors.white38),
            const SizedBox(height: 32),
            Text(
              'Request Timed Out',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'The tutor did not respond. Please try scanning again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onRetry,
                child: const Text('Go Back', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
