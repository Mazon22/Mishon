import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

enum AppLanguage { ru, en }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.ru ? 'ru' : 'en';

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return code == 'en' ? AppLanguage.en : AppLanguage.ru;
  }
}

@immutable
class AppSettingsState {
  final AppLanguage language;
  final bool profileAutoRefresh;
  final bool motionEffects;
  final bool messagePreviews;

  const AppSettingsState({
    this.language = AppLanguage.ru,
    this.profileAutoRefresh = true,
    this.motionEffects = true,
    this.messagePreviews = true,
  });

  Locale get locale => language.locale;

  AppSettingsState copyWith({
    AppLanguage? language,
    bool? profileAutoRefresh,
    bool? motionEffects,
    bool? messagePreviews,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      profileAutoRefresh: profileAutoRefresh ?? this.profileAutoRefresh,
      motionEffects: motionEffects ?? this.motionEffects,
      messagePreviews: messagePreviews ?? this.messagePreviews,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final SecureStorage _storage;

  AppSettingsNotifier(this._storage) : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final languageCode = await _storage.readAppLanguage();
    final profileAutoRefresh = await _storage.readBooleanSetting(
      'settings_profile_auto_refresh',
    );
    final motionEffects = await _storage.readBooleanSetting(
      'settings_motion_effects',
    );
    final messagePreviews = await _storage.readBooleanSetting(
      'settings_message_previews',
    );

    final nextState = state.copyWith(
      language: AppLanguageX.fromCode(languageCode),
      profileAutoRefresh: profileAutoRefresh ?? state.profileAutoRefresh,
      motionEffects: motionEffects ?? state.motionEffects,
      messagePreviews: messagePreviews ?? state.messagePreviews,
    );

    Intl.defaultLocale = nextState.language.code;
    state = nextState;
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    Intl.defaultLocale = language.code;
    await _storage.writeAppLanguage(language.code);
  }

  Future<void> setProfileAutoRefresh(bool value) async {
    state = state.copyWith(profileAutoRefresh: value);
    await _storage.writeBooleanSetting('settings_profile_auto_refresh', value);
  }

  Future<void> setMotionEffects(bool value) async {
    state = state.copyWith(motionEffects: value);
    await _storage.writeBooleanSetting('settings_motion_effects', value);
  }

  Future<void> setMessagePreviews(bool value) async {
    state = state.copyWith(messagePreviews: value);
    await _storage.writeBooleanSetting('settings_message_previews', value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      return AppSettingsNotifier(ref.watch(storageProvider));
    });
