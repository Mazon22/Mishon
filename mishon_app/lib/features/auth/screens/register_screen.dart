import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/widgets/buttons.dart';
import 'package:mishon_app/core/widgets/text_fields.dart';
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
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final success = await ref.read(authNotifierProvider.notifier).register(
          _usernameController.text.trim(),
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
      if (error.contains('Email уже используется')) {
        return 'Этот email уже зарегистрирован';
      }
      if (error.contains('Имя пользователя уже занято')) {
        return 'Это имя пользователя уже занято';
      }
      return error;
    }
    return 'Ошибка регистрации. Проверьте подключение к интернету.';
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
                          'Создать аккаунт',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Присоединяйтесь к Mishon',
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
                          controller: _usernameController,
                          labelText: 'Имя пользователя',
                          hintText: 'username',
                          prefixIcon: Icons.person_outlined,
                          helperText: '3-50 символов, только буквы, цифры и _',
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите имя';
                            if (v.length < 3) return 'Минимум 3 символа';
                            if (v.length > 50) return 'Максимум 50 символов';
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                              return 'Только буквы, цифры и подчёркивание';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                          hintText: 'Минимум 8 символов',
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите пароль';
                            if (v.length < 8) return 'Минимум 8 символов';
                            if (!v.contains(RegExp(r'[A-Z]'))) {
                              return 'Нужна заглавная буква';
                            }
                            if (!v.contains(RegExp(r'[a-z]'))) {
                              return 'Нужна строчная буква';
                            }
                            if (!v.contains(RegExp(r'\d'))) return 'Нужна цифра';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppPasswordField(
                          controller: _confirmPasswordController,
                          labelText: 'Подтвердите пароль',
                          hintText: 'Повторите пароль',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Пароли не совпадают';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Кнопка регистрации
                        PrimaryButton(
                          text: 'Зарегистрироваться',
                          onPressed: _register,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Переход на вход
                        Center(
                          child: TextButton(
                            onPressed: isLoading ? null : () => context.go('/login'),
                            child: const Text('Есть аккаунт? Войти'),
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
