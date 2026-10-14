import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/staggered.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) {
      await Haptics.warning();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text.trim(), _password.text);
      // The router redirects once the auth state changes.
    } on ApiException catch (e) {
      await Haptics.warning();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email and we'll send you a reset link."),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: controller,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Send link')),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      final message = await ref.read(authRepositoryProvider).forgotPassword(email);
      if (mounted) showAppSnack(context, message);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fields = <Widget>[
      Text('Welcome back', style: context.text.displaySmall),
      const SizedBox(height: AppSpacing.sm),
      Text('Sign in to keep your streak alive.', style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
      const SizedBox(height: AppSpacing.xxl),
      AppTextField(
        label: 'Email',
        controller: _email,
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: Validators.email,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Password',
        controller: _password,
        icon: Icons.lock_outline_rounded,
        obscure: true,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        validator: Validators.required('Enter your password'),
        onSubmitted: (_) => _submit(),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
      ),
      AuthErrorBanner(message: _error),
      const SizedBox(height: AppSpacing.lg),
      GradientButton(label: 'Sign in', onPressed: _submit, loading: _loading),
      const SizedBox(height: AppSpacing.xl),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('New to IronRank?', style: context.text.bodyMedium),
          TextButton(onPressed: () => context.go(Routes.register), child: const Text('Create account')),
        ],
      ),
    ];

    return AuthScaffold(
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < fields.length; i++) fields[i].staggered(i)],
          ),
        ),
      ),
    );
  }
}
