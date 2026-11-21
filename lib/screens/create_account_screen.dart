/// Create account — screen 24 (mobile + web).
///
/// One registry, every device. "Move my guest data in" is checked by
/// default. v0.1 auth is local-only (no backend).
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscured = true;
  bool _moveGuestData = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
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
            const SizedBox(height: 16),
            Text(
              'One registry,\nevery device.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Team registry, CI integration, and shared waivers. '
              'Free plan.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 16),
            _label(context, 'Your name'),
            TextField(
              controller: _nameController,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(hintText: 'Vishwet'),
            ),
            const SizedBox(height: 12),
            _label(context, 'Email'),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 12),
            _label(context, 'Password'),
            TextField(
              controller: _passwordController,
              obscureText: _obscured,
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 12),
            GlassCard(
              child: InkWell(
                onTap: () =>
                    setState(() => _moveGuestData = !_moveGuestData),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: _moveGuestData
                            ? p.accentGradient
                            : null,
                        color:
                            _moveGuestData ? null : p.glassStrong,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _moveGuestData
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Move my guest data in',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${controller.reports.length} reports · '
                            '${controller.rules.length} rules · '
                            '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} '
                            'with ${controller.waiversCount == 1 ? 'its' : 'their'} reason — '
                            'everything on this device joins the account.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: p.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Create account',
              onPressed: () {
                final error = controller.startCreateAccount(
                  name: _nameController.text,
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                );
                if (error != null) {
                  setState(() => _error = error);
                  return;
                }
                Navigator.pushNamed(
                  context,
                  '/verify',
                  arguments: {'moveGuestData': _moveGuestData},
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or sign up with',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FpGhostButton(
                    label: 'Apple',
                    icon: Icons.apple,
                    onPressed: () => showFpSnack(
                      context,
                      'Apple sign-up is a demo in v0.1 — use email.',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: 'Google',
                    icon: Icons.g_mobiledata,
                    onPressed: () => showFpSnack(
                      context,
                      'Google sign-up is a demo in v0.1 — use email.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'By creating an account you agree to the terms.\n'
                'Your reports stay yours — export or delete, any time.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
