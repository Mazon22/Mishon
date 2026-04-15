import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/widgets/auth_legal_block.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';
import 'package:mishon_app/features/auth/widgets/auth_social_section.dart';

import '../auth_flow_destination.dart';
import '../providers/auth_provider.dart';

enum _AvailabilityState { idle, checking, available, unavailable, error }

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
  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  int _usernameRequestSeq = 0;
  int _emailRequestSeq = 0;
  _AvailabilityState _usernameAvailabilityState = _AvailabilityState.idle;
  _AvailabilityState _emailAvailabilityState = _AvailabilityState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_clearErrorMessage);
    _confirmPasswordController.addListener(_clearErrorMessage);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _emailController.removeListener(_onEmailChanged);
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

  void _onUsernameChanged() {
    _clearErrorMessage();
    _scheduleUsernameAvailabilityCheck();
  }

  void _onEmailChanged() {
    _clearErrorMessage();
    _scheduleEmailAvailabilityCheck();
  }

  bool _isUsernameSyntaxValid(String username) {
    if (username.isEmpty || username.length < 5 || username.length > 32) {
      return false;
    }

    return RegExp(
      r'^(?!.*\.\.)(?!\.)(?!.*\.$)[a-z0-9._]{5,32}$',
    ).hasMatch(username);
  }

  bool _isEmailSyntaxValid(String email) {
    if (email.isEmpty) {
      return false;
    }

    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _scheduleUsernameAvailabilityCheck() {
    _usernameDebounce?.cancel();
    final username = _usernameController.text.trim();
    if (!_isUsernameSyntaxValid(username)) {
      if (_usernameAvailabilityState != _AvailabilityState.idle && mounted) {
        setState(() => _usernameAvailabilityState = _AvailabilityState.idle);
      }
      return;
    }

    final requestSeq = ++_usernameRequestSeq;
    if (mounted) {
      setState(() => _usernameAvailabilityState = _AvailabilityState.checking);
    }

    final repository = ref.read(authRepositoryProvider);
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(
        _resolveUsernameAvailability(
          repository: repository,
          username: username,
          requestSeq: requestSeq,
        ),
      );
    });
  }

  void _scheduleEmailAvailabilityCheck() {
    _emailDebounce?.cancel();
    final email = _emailController.text.trim();
    if (!_isEmailSyntaxValid(email)) {
      if (_emailAvailabilityState != _AvailabilityState.idle && mounted) {
        setState(() => _emailAvailabilityState = _AvailabilityState.idle);
      }
      return;
    }

    final requestSeq = ++_emailRequestSeq;
    if (mounted) {
      setState(() => _emailAvailabilityState = _AvailabilityState.checking);
    }

    final repository = ref.read(authRepositoryProvider);
    _emailDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(
        _resolveEmailAvailability(
          repository: repository,
          email: email,
          requestSeq: requestSeq,
        ),
      );
    });
  }

  Future<void> _resolveUsernameAvailability({
    required AuthRepository repository,
    required String username,
    required int requestSeq,
    bool immediate = false,
  }) async {
    try {
      if (immediate) {
        _usernameDebounce?.cancel();
        if (!mounted) {
          return;
        }
        setState(
          () => _usernameAvailabilityState = _AvailabilityState.checking,
        );
      }

      final available = await repository.checkRegistrationUsernameAvailability(
        username,
      );

      if (!mounted ||
          requestSeq != _usernameRequestSeq ||
          _usernameController.text.trim() != username) {
        return;
      }

      setState(
        () =>
            _usernameAvailabilityState =
                available
                    ? _AvailabilityState.available
                    : _AvailabilityState.unavailable,
      );
    } catch (_) {
      if (!mounted ||
          requestSeq != _usernameRequestSeq ||
          _usernameController.text.trim() != username) {
        return;
      }

      setState(() => _usernameAvailabilityState = _AvailabilityState.error);
    }
  }

  Future<void> _resolveEmailAvailability({
    required AuthRepository repository,
    required String email,
    required int requestSeq,
    bool immediate = false,
  }) async {
    try {
      if (immediate) {
        _emailDebounce?.cancel();
        if (!mounted) {
          return;
        }
        setState(() => _emailAvailabilityState = _AvailabilityState.checking);
      }

      final available = await repository.checkRegistrationEmailAvailability(
        email,
      );

      if (!mounted ||
          requestSeq != _emailRequestSeq ||
          _emailController.text.trim() != email) {
        return;
      }

      setState(
        () =>
            _emailAvailabilityState =
                available
                    ? _AvailabilityState.available
                    : _AvailabilityState.unavailable,
      );
    } catch (_) {
      if (!mounted ||
          requestSeq != _emailRequestSeq ||
          _emailController.text.trim() != email) {
        return;
      }

      setState(() => _emailAvailabilityState = _AvailabilityState.error);
    }
  }

  Future<bool> _ensureAvailabilityBeforeRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final repository = ref.read(authRepositoryProvider);

    if (_isUsernameSyntaxValid(username)) {
      await _resolveUsernameAvailability(
        repository: repository,
        username: username,
        requestSeq: ++_usernameRequestSeq,
        immediate: true,
      );
    }

    if (_isEmailSyntaxValid(email)) {
      await _resolveEmailAvailability(
        repository: repository,
        email: email,
        requestSeq: ++_emailRequestSeq,
        immediate: true,
      );
    }

    if (_usernameAvailabilityState == _AvailabilityState.unavailable ||
        _emailAvailabilityState == _AvailabilityState.unavailable) {
      return false;
    }

    return true;
  }

  Future<void> _register() async {
    final strings = AppStrings.of(context);
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    if (!await _ensureAvailabilityBeforeRegister()) {
      setState(() {
        _errorMessage =
            _usernameAvailabilityState == _AvailabilityState.unavailable
                ? strings.usernameUnavailable
                : strings.emailUnavailable;
      });
      return;
    }

    if (!mounted) {
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
      final response = ref.read(authNotifierProvider).valueOrNull;
      if (response != null) {
        context.go(
          resolvePostAuthDestination(
            response: response,
            onboardingCompleted: false,
          ),
        );
        return;
      }
      context.go('/onboarding');
      return;
    }

    final message = ref
        .read(authNotifierProvider)
        .when<String?>(
          data: (_) => null,
          error:
              (error, _) => formatAuthErrorMessage(
                error,
                fallback: strings.operationError,
              ),
          loading: () => null,
        );

    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return AuthScreenShell(
      title: strings.createAccountTitle,
      subtitle: strings.createAccountSubtitle,
      children: [
        const AuthSocialSection(),
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
                labelText: strings.username,
                hintText:
                    strings.isRu ? 'Введите username' : 'Enter a username',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) {
                    return strings.chooseUsernameValidation;
                  }
                  if (username.length < 5) {
                    return strings.usernameMinThreeValidation;
                  }
                  if (username.length > 32) {
                    return strings.usernameMaxFiftyValidation;
                  }
                  if (!_isUsernameSyntaxValid(username)) {
                    return strings.usernameCharactersValidation;
                  }
                  return null;
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildAvailabilityHint(
                  key: ValueKey('username-${_usernameAvailabilityState.name}'),
                  status: _usernameAvailabilityState,
                  checkingText: strings.checkingUsername,
                  availableText: strings.usernameAvailable,
                  unavailableText: strings.usernameUnavailable,
                  failedText: strings.usernameVerifyFailed,
                ),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailController,
                labelText: strings.emailAddress,
                hintText: strings.isRu ? 'Введите почту' : 'Enter your email',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return strings.enterEmailValidation;
                  }
                  if (!_isEmailSyntaxValid(email)) {
                    return strings.emailInvalidValidation;
                  }
                  return null;
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildAvailabilityHint(
                  key: ValueKey('email-${_emailAvailabilityState.name}'),
                  status: _emailAvailabilityState,
                  checkingText: strings.checkingEmail,
                  availableText: strings.emailAvailable,
                  unavailableText: strings.emailUnavailable,
                  failedText: strings.emailVerifyFailed,
                ),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordController,
                labelText: strings.passwordLabel,
                hintText:
                    strings.isRu ? 'Введите пароль' : 'Enter your password',
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
                  if (!password.contains(RegExp(r'[A-Z]'))) {
                    return strings.passwordUppercaseValidation;
                  }
                  if (!password.contains(RegExp(r'[a-z]'))) {
                    return strings.passwordLowercaseValidation;
                  }
                  if (!password.contains(RegExp(r'\d'))) {
                    return strings.passwordNumberValidation;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmPasswordController,
                labelText: strings.confirmNewPasswordLabel,
                hintText:
                    strings.isRu ? 'Повторите пароль' : 'Repeat your password',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
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
              const SizedBox(height: 20),
              AuthPrimaryButton(
                text: strings.createAccountAction,
                onPressed: _register,
                isLoading: isLoading,
              ),
              const SizedBox(height: 12),
              const AuthLegalBlock(),
              const SizedBox(height: 18),
              AuthFooter(
                label: strings.alreadyHaveAccountLabel,
                action: strings.signInAction,
                onTap: isLoading ? null : () => context.go('/login'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityHint({
    required Key key,
    required _AvailabilityState status,
    required String checkingText,
    required String availableText,
    required String unavailableText,
    required String failedText,
  }) {
    if (status == _AvailabilityState.idle) {
      return const SizedBox.shrink();
    }

    final (icon, color, text) = switch (status) {
      _AvailabilityState.idle => (
        Icons.info_outline_rounded,
        Theme.of(context).colorScheme.tertiary,
        failedText,
      ),
      _AvailabilityState.checking => (
        Icons.hourglass_top_rounded,
        Theme.of(context).colorScheme.primary,
        checkingText,
      ),
      _AvailabilityState.available => (
        Icons.check_circle_rounded,
        const Color(0xFF198754),
        availableText,
      ),
      _AvailabilityState.unavailable => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
        unavailableText,
      ),
      _AvailabilityState.error => (
        Icons.info_outline_rounded,
        Theme.of(context).colorScheme.tertiary,
        failedText,
      ),
    };

    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 12, top: 8, right: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
