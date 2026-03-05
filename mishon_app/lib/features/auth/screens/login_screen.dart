import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/widgets/buttons.dart';
import 'package:mishon_app/core/widgets/text_fields.dart';
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final success = await ref.read(authNotifierProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (mounted) {
      if (success) {
        context.go('/feed');
      } else {
        final state = ref.read(authNotifierProvider);
        setState(() {
          _errorMessage = state.when(
            data: (_) => null,
            error: (error, _) => _getErrorMessage(error),
            loading: () => null,
          );
        });
      }
    }
  }

  String _getErrorMessage(Object error) {
    if (error is String) {
      if (error.contains('Неверный email или пароль')) {
        return 'Неверный email или пароль';
      }
      return error;
    }
    return 'Ошибка входа. Проверьте подключение к интернету.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Логотип
                        const Icon(
                          Icons.rocket_launch_outlined,
                          size: 56,
                          color: Color(0xFF1DA1F2),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Вход в Mishon',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Войдите для продолжения',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Сообщение об ошибке
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Поля ввода
                        AppTextField(
                          controller: _emailController,
                          labelText: 'Email',
                          hintText: 'example@mail.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите email';
                            if (!v.contains('@')) return 'Некорректный email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppPasswordField(
                          controller: _passwordController,
                          labelText: 'Пароль',
                          hintText: 'Введите пароль',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 24),

                        // Кнопка входа
                        PrimaryButton(
                          text: 'Войти',
                          onPressed: _login,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Переход на регистрацию
                        Center(
                          child: TextButton(
                            onPressed: isLoading ? null : () => context.go('/register'),
                            child: const Text('Нет аккаунта? Зарегистрироваться'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
