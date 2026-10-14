import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/staggered.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  ApiException? _apiError;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _apiError = null;
    });
    if (!_form.currentState!.validate()) {
      await Haptics.warning();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(_email.text.trim(), _password.text, _username.text.trim());
    } on ApiException catch (e) {
      await Haptics.warning();
      if (mounted) {
        setState(() {
          _apiError = e;
          // Field-level messages render under their fields; anything else goes in the banner.
          final fieldLevel = e.fieldError('body.email') ?? e.fieldError('body.password') ?? e.fieldError('body.username');
          _error = fieldLevel == null ? (e.code == 'EMAIL_TAKEN' ? null : e.message) : null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final emailTaken = _apiError?.code == 'EMAIL_TAKEN' ? _apiError!.message : null;
    final fields = <Widget>[
      Text('Create account', style: context.text.displaySmall),
      const SizedBox(height: AppSpacing.sm),
      Text('Two minutes to set up. A lifetime of PRs.', style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
      const SizedBox(height: AppSpacing.xxl),
      AppTextField(
        label: 'Username',
        controller: _username,
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username],
        validator: Validators.username,
        errorText: _apiError?.fieldError('body.username'),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Email',
        controller: _email,
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: Validators.email,
        errorText: emailTaken ?? _apiError?.fieldError('body.email'),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Password',
        hint: 'At least 8 characters',
        controller: _password,
        icon: Icons.lock_outline_rounded,
        obscure: true,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        validator: Validators.password,
        errorText: _apiError?.fieldError('body.password'),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: AppSpacing.lg),
      AuthErrorBanner(message: _error),
      const SizedBox(height: AppSpacing.sm),
      GradientButton(label: 'Create account', onPressed: _submit, loading: _loading),
      const SizedBox(height: AppSpacing.xl),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Already lifting with us?', style: context.text.bodyMedium),
          TextButton(onPressed: () => context.go(Routes.login), child: const Text('Sign in')),
        ],
      ),
    ];

    return AuthScaffold(
      onBack: () => context.go(Routes.login),
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
