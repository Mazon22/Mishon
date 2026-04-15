import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(_emailController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitted = true;
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

    if (_isSubmitted) {
      return AuthScreenShell(
        title: strings.forgotPasswordSuccessTitle,
        subtitle: strings.forgotPasswordSuccessSubtitle,
        children: [
          AuthPrimaryButton(
            text: strings.backToLogin,
            onPressed: () => context.go('/login'),
          ),
        ],
      );
    }

    return AuthScreenShell(
      title: strings.forgotPasswordTitle,
      subtitle: strings.forgotPasswordSubtitle,
      children: [
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
                controller: _emailController,
                labelText: strings.emailAddress,
                hintText: strings.isRu ? 'Введите почту' : 'Enter your email',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return strings.enterEmailValidation;
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return strings.emailInvalidValidation;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AuthPrimaryButton(
                text: strings.sendResetLink,
                onPressed: _submit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
              AuthFooter(
                label: strings.rememberedPassword,
                action: strings.backToLogin,
                onTap: _isLoading ? null : () => context.go('/login'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
