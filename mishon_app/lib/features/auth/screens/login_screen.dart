import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorMessage);
    _passwordController.addListener(_clearErrorMessage);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearErrorMessage);
    _passwordController.removeListener(_clearErrorMessage);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _login() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/feed');
      return;
    }

    final state = ref.read(authNotifierProvider);
    final message = state.when<String?>(
      data: (_) => null,
      error:
          (error, _) => formatAuthErrorMessage(
            error,
            fallback: 'Unable to sign in right now. Please try again.',
          ),
      loading: () => null,
    );

    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return AuthScreenShell(
      title: 'Sign in to Mishon',
      subtitle: 'Continue to your account',
      children: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child:
                    _errorMessage == null
                        ? const SizedBox.shrink()
                        : Padding(
                          key: ValueKey(_errorMessage),
                          padding: const EdgeInsets.only(bottom: 20),
                          child: AuthErrorBanner(message: _errorMessage!),
                        ),
              ),
              AuthTextField(
                controller: _emailController,
                labelText: 'Email',
                hintText: 'you@example.com',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Enter your email.';
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Enter your password.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                text: 'Sign In',
                onPressed: _login,
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
              AuthFooter(
                label: 'Don\'t have an account?',
                action: 'Sign up',
                onTap: isLoading ? null : () => context.go('/register'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
