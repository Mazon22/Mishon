import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_strings.dart';
import 'core/providers/app_bootstrap_provider.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings_provider.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем статус бар для Web
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase отключён для MVP
  runApp(const ProviderScope(child: MishonApp()));
}

class MishonApp extends ConsumerWidget {
  const MishonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final bootstrapState = ref.watch(appBootstrapProvider);

    if (!bootstrapState.allowsInteraction) {
      return MaterialApp(
        onGenerateTitle: (context) => AppStrings.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: settings.locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _BootstrapScreen(state: bootstrapState),
      );
    }

    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppStrings.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: settings.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  final AppBootstrapState state;

  const _BootstrapScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FBFF), Color(0xFFF0EEFF), Color(0xFFEAF4FF)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF22C1C3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Mishon',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF16243A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _phaseLabel(strings, state.phase),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5D6E86),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _phaseLabel(AppStrings strings, AppBootstrapPhase phase) {
    return switch (phase) {
      AppBootstrapPhase.initializingServices =>
        strings.bootstrapInitializingServices,
      AppBootstrapPhase.checkingConnectivity =>
        strings.bootstrapCheckingNetwork,
      AppBootstrapPhase.preloadingCachedData => strings.bootstrapRestoringCache,
      AppBootstrapPhase.preloadingRemoteData => strings.bootstrapPreloadingData,
      _ => strings.bootstrapPreparingApp,
    };
  }
}
