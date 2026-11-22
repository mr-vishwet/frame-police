/// Verify — screen 25 (mobile + web).
///
/// Magic link or 6-digit code, works on any device. v0.1 has no email
/// backend: any 6-digit code verifies locally, and the screen says so.
/// Guest data is safe while you wait.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The verify screen screen.
class VerifyScreen extends StatefulWidget {
  /// Creates a [VerifyScreen].
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _verifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final pending = controller.pendingAccount;
    const p = AppTheme.palette;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final moveGuestData = args?['moveGuestData'] as bool? ?? true;
    return FpScaffold(
      title: 'Verify',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Check your inbox'),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineMedium,
                children: [
                  const TextSpan(text: 'We sent a magic link to '),
                  TextSpan(
                    text: pending?.email ?? 'your email',
                    style: AppTheme.mono(size: 20, color: p.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the link in the email — or type the 6-digit code '
              'below. The link works on any device.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: AppTheme.mono(size: 28, color: p.ink),
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
              ),
              maxLength: 6,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'v0.1 demo: any 6-digit code verifies locally — there '
                'is no email backend yet.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: p.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            FpPrimaryButton(
              label: _verifying ? 'Verifying…' : 'Verify and continue',
              onPressed: _verifying
                  ? null
                  : () => _verify(controller, moveGuestData),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => showFpSnack(
                    context,
                    'Code re-sent (demo — any 6-digit code works).',
                  ),
                  child: const Text('Resend code'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Wrong email? Change it'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('While you wait'),
                  const SizedBox(height: 6),
                  Text(
                    'Your guest data is safe on this device — '
                    '${controller.reports.length} reports, '
                    '${controller.rules.length} rules, '
                    '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'}. '
                    'Verification only links the account; it moves '
                    'nothing until you say so.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify(AppController controller, bool moveGuestData) async {
    setState(() => _verifying = true);
    try {
      final error = await controller.verifyCode(_codeController.text);
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      Navigator.pushNamed(
        context,
        '/migrate',
        arguments: {'moveGuestData': moveGuestData},
      );
    } on Object catch (_) {
      // Storing the session failed (secure storage unavailable): show
      // it instead of leaving the button stuck on "Verifying…".
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}
