import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

class VerifyEmailResultScreen extends ConsumerStatefulWidget {
  final String? token;

  const VerifyEmailResultScreen({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailResultScreen> createState() =>
      _VerifyEmailResultScreenState();
}

class _VerifyEmailResultScreenState
    extends ConsumerState<VerifyEmailResultScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = AppStrings.of(context).verificationLinkInvalid;
      });
      return;
    }

    try {
      await ref.read(authRepositoryProvider).verifyEmail(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _message = AppStrings.of(context).verificationSuccessSubtitle;
      });
    } on ApiException catch (error) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = error.apiError.message;
      });
    } on OfflineException catch (error) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = error.message;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = AppStrings.of(context).operationError;
      });
    }
  }

  void _continue() {
    final isAuthenticated = ref.read(appBootstrapProvider).isAuthenticated;
    context.go(_isSuccess && isAuthenticated ? '/onboarding' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AuthScreenShell(
      title:
          _isLoading
              ? strings.verificationInProgressTitle
              : _isSuccess
              ? strings.verificationSuccessTitle
              : strings.verificationFailedTitle,
      subtitle: _message ?? '',
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          AuthPrimaryButton(
            text: strings.continueToApp,
            onPressed: _continue,
          ),
      ],
    );
  }
}
