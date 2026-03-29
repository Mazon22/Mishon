import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_service.dart';
import 'core/localization/app_strings.dart';
import 'core/providers/app_bootstrap_provider.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_security_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MishonApp()));
}

class MishonApp extends ConsumerStatefulWidget {
  const MishonApp({super.key});

  @override
  ConsumerState<MishonApp> createState() => _MishonAppState();
}

class _MishonAppState extends ConsumerState<MishonApp> {
  bool _didInitFirebase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didInitFirebase) {
        return;
      }
      _didInitFirebase = true;
      final firebaseService = ref.read(firebaseServiceProvider);
      if (kIsWeb && !FirebaseService.hasWebFirebaseOptions) {
        return;
      }
      unawaited(firebaseService.initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final bootstrapState = ref.watch(appBootstrapProvider);
    final router = ref.watch(goRouterProvider);

    ref.listen<AsyncValue<PushRouteIntent>>(pushRouteIntentProvider, (
      _,
      next,
    ) {
      next.whenData((intent) {
        if (!ref.read(appBootstrapProvider).allowsInteraction) {
          return;
        }
        router.go(intent.location);
      });
    });

    ref.listen<bool>(
      appBootstrapProvider.select((state) => state.isAuthenticated),
      (previous, next) {
        if (next && previous != next) {
          unawaited(ref.read(firebaseServiceProvider).syncTokenIfPossible());
        }
      },
    );

    if (!bootstrapState.allowsInteraction) {
      return _buildBootstrapApp(settings, bootstrapState);
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppStrings.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder:
          (context, child) =>
              AppSecurityShell(child: child ?? const SizedBox.shrink()),
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

  MaterialApp _buildBootstrapApp(
    AppSettingsState settings,
    AppBootstrapState bootstrapState,
  ) {
    Route<dynamic> buildBootstrapRoute(RouteSettings routeSettings) {
      return MaterialPageRoute<void>(
        settings: routeSettings,
        builder: (_) => _BootstrapScreen(state: bootstrapState),
      );
    }

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
      onGenerateRoute: buildBootstrapRoute,
      onUnknownRoute: buildBootstrapRoute,
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
