import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

class VerifyEmailPendingScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailPendingScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailPendingScreen> createState() =>
      _VerifyEmailPendingScreenState();
}

class _VerifyEmailPendingScreenState
    extends ConsumerState<VerifyEmailPendingScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _resend() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resendVerification(widget.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = AppStrings.of(context).verificationEmailResent;
        _statusIsError = false;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      setState(() {
        _statusMessage = error.apiError.message;
        _statusIsError = true;
        _isLoading = false;
      });
    } on OfflineException catch (error) {
      setState(() {
        _statusMessage = error.message;
        _statusIsError = true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _statusMessage = AppStrings.of(context).operationError;
        _statusIsError = true;
        _isLoading = false;
      });
    }
  }

  void _continue() {
    final isAuthenticated = ref.read(appBootstrapProvider).isAuthenticated;
    context.go(isAuthenticated ? '/onboarding' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AuthScreenShell(
      title: strings.verifyEmailPendingTitle,
      subtitle: strings.verifyEmailPendingSubtitle(widget.email),
      children: [
        if (_statusMessage != null) ...[
          if (_statusIsError)
            AuthErrorBanner(message: _statusMessage!)
          else
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF256C4B),
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 20),
        ],
        AuthPrimaryButton(
          text: strings.resendVerificationEmail,
          onPressed: _resend,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          text: strings.continueToApp,
          onPressed: _continue,
        ),
      ],
    );
  }
}
