/// Sign in — screen 23 (mobile + web).
///
/// Join the team registry. Guest data moves over with you. v0.1 auth
/// is local-only (no backend) — the form validates, then verification
/// links the account. Apple / Google buttons are shown as the design
/// requires; in v0.1 they route to the same local sign-in.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscured = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = AppTheme.palette;
    return FpScaffold(
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const FpLogoMark(size: 44),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FRAME POLICE',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Registry $kRegistryVersion · $kRuleCount rules',
                      style: AppTheme.mono(size: 11, color: p.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to\njoin the team registry.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${controller.reports.length} reports and '
              '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} '
              'on this device move into your account. Nothing is lost.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 20),
            Text(
              'EMAIL',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'PASSWORD',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscured,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: 'At least 8 characters',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscured = !_obscured),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showFpSnack(
                  context,
                  'Password reset needs the account backend (phase 2). '
                  'Your local data is unaffected.',
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: p.red, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            FpPrimaryButton(
              label: 'Sign in',
              onPressed: () => _signIn(controller),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FpGhostButton(
                    label: 'Apple',
                    icon: Icons.apple,
                    onPressed: () => _socialSignIn(controller, 'Apple'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: 'Google',
                    icon: Icons.g_mobiledata,
                    onPressed: () => _socialSignIn(controller, 'Google'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/create-account',
                  ),
                  child: const Text('New here? Create an account'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/guest',
                  ),
                  child: const Text('Continue as guest'),
                ),
              ],
            ),
            Center(
              child: Text(
                'v0.1: sign-in is local-only — no backend yet. Your '
                'password never leaves this device.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _signIn(AppController controller) {
    final error = controller.startSignIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pushNamed(context, '/verify');
  }

  void _socialSignIn(AppController controller, String provider) {
    // v0.1: no OAuth backend — route to the same local verification
    // with a provider-derived placeholder email.
    final error = controller.startSignIn(
      email: 'you@${provider.toLowerCase()}.example',
      password: 'social-sign-in',
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    showFpSnack(
      context,
      '$provider sign-in is a demo in v0.1 — verification is local.',
    );
    Navigator.pushNamed(context, '/verify');
  }
}
