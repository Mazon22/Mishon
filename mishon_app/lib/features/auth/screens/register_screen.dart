import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearErrorMessage);
    _emailController.addListener(_clearErrorMessage);
    _passwordController.addListener(_clearErrorMessage);
    _confirmPasswordController.addListener(_clearErrorMessage);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearErrorMessage);
    _emailController.removeListener(_clearErrorMessage);
    _passwordController.removeListener(_clearErrorMessage);
    _confirmPasswordController.removeListener(_clearErrorMessage);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _register() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );

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
            fallback:
                'Unable to create your account right now. Please try again.',
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
      title: 'Create your account',
      subtitle: 'Join Mishon with a clean, secure setup.',
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
                controller: _usernameController,
                labelText: 'Username',
                hintText: 'michael_design',
                prefixIcon: Icons.person_outline_rounded,
                helperText:
                    '3-50 characters. Letters, numbers, and underscores only.',
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) {
                    return 'Choose a username.';
                  }
                  if (username.length < 3) {
                    return 'Use at least 3 characters.';
                  }
                  if (username.length > 50) {
                    return 'Use 50 characters or fewer.';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                    return 'Use only letters, numbers, and underscores.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                hintText: 'Create a secure password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) {
                    return 'Create a password.';
                  }
                  if (password.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  if (!password.contains(RegExp(r'[A-Z]'))) {
                    return 'Include at least one uppercase letter.';
                  }
                  if (!password.contains(RegExp(r'[a-z]'))) {
                    return 'Include at least one lowercase letter.';
                  }
                  if (!password.contains(RegExp(r'\d'))) {
                    return 'Include at least one number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm password',
                hintText: 'Repeat your password',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Confirm your password.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                text: 'Create Account',
                onPressed: _register,
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
              AuthFooter(
                label: 'Already have an account?',
                action: 'Sign in',
                onTap: isLoading ? null : () => context.go('/login'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
