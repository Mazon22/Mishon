import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token == null || widget.token!.trim().isEmpty) {
      setState(() {
        _errorMessage = AppStrings.of(context).invalidOrExpiredResetLink;
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            widget.token!.trim(),
            _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = AppStrings.of(context).operationError;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_isSuccess) {
      return AuthScreenShell(
        title: strings.resetPasswordSuccessTitle,
        subtitle: strings.resetPasswordSuccessSubtitle,
        children: [
          AuthPrimaryButton(
            text: strings.backToLogin,
            onPressed: () => context.go('/login'),
          ),
        ],
      );
    }

    final missingToken = widget.token == null || widget.token!.trim().isEmpty;

    return AuthScreenShell(
      title: strings.resetPasswordTitle,
      subtitle:
          missingToken
              ? strings.invalidOrExpiredResetLink
              : strings.resetPasswordSubtitle,
      children: [
        if (!missingToken)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  AuthErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 20),
                ],
                AuthTextField(
                  controller: _passwordController,
                  labelText: strings.newPasswordLabel,
                  hintText: strings.newPasswordHint,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) {
                      return strings.enterPasswordValidation;
                    }
                    if (password.length < 8) {
                      return strings.passwordLengthValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmController,
                  labelText: strings.confirmNewPasswordLabel,
                  hintText: strings.confirmPasswordHint,
                  prefixIcon: Icons.verified_user_outlined,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return strings.confirmPasswordValidation;
                    }
                    if (value != _passwordController.text) {
                      return strings.passwordMismatchValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  text: strings.resetPasswordAction,
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
              ],
            ),
          )
        else
          AuthPrimaryButton(
            text: strings.backToLogin,
            onPressed: () => context.go('/login'),
          ),
      ],
    );
  }
}
