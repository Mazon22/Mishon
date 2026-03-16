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
  final bool passcodeLockEnabled;
  final int autoLockMinutes;

  const AppSettingsState({
    this.language = AppLanguage.ru,
    this.profileAutoRefresh = true,
    this.motionEffects = true,
    this.messagePreviews = true,
    this.passcodeLockEnabled = false,
    this.autoLockMinutes = 1,
  });

  Locale get locale => language.locale;

  AppSettingsState copyWith({
    AppLanguage? language,
    bool? profileAutoRefresh,
    bool? motionEffects,
    bool? messagePreviews,
    bool? passcodeLockEnabled,
    int? autoLockMinutes,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      profileAutoRefresh: profileAutoRefresh ?? this.profileAutoRefresh,
      motionEffects: motionEffects ?? this.motionEffects,
      messagePreviews: messagePreviews ?? this.messagePreviews,
      passcodeLockEnabled: passcodeLockEnabled ?? this.passcodeLockEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  static const _profileAutoRefreshKey = 'settings_profile_auto_refresh';
  static const _motionEffectsKey = 'settings_motion_effects';
  static const _messagePreviewsKey = 'settings_message_previews';
  static const _passcodeKey = 'settings_app_passcode';
  static const _autoLockMinutesKey = 'settings_auto_lock_minutes';

  final SecureStorage _storage;

  AppSettingsNotifier(this._storage) : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final languageCode = await _storage.readAppLanguage();
    final profileAutoRefresh = await _storage.readBooleanSetting(
      _profileAutoRefreshKey,
    );
    final motionEffects = await _storage.readBooleanSetting(_motionEffectsKey);
    final messagePreviews = await _storage.readBooleanSetting(
      _messagePreviewsKey,
    );
    final passcode = await _storage.readStringSetting(_passcodeKey);
    final autoLockMinutes = await _storage.readIntSetting(_autoLockMinutesKey);

    final nextState = state.copyWith(
      language: AppLanguageX.fromCode(languageCode),
      profileAutoRefresh: profileAutoRefresh ?? state.profileAutoRefresh,
      motionEffects: motionEffects ?? state.motionEffects,
      messagePreviews: messagePreviews ?? state.messagePreviews,
      passcodeLockEnabled: (passcode?.isNotEmpty ?? false),
      autoLockMinutes: autoLockMinutes ?? state.autoLockMinutes,
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
    await _storage.writeBooleanSetting(_profileAutoRefreshKey, value);
  }

  Future<void> setMotionEffects(bool value) async {
    state = state.copyWith(motionEffects: value);
    await _storage.writeBooleanSetting(_motionEffectsKey, value);
  }

  Future<void> setMessagePreviews(bool value) async {
    state = state.copyWith(messagePreviews: value);
    await _storage.writeBooleanSetting(_messagePreviewsKey, value);
  }

  Future<void> enablePasscode(String code) async {
    state = state.copyWith(passcodeLockEnabled: true);
    await _storage.writeStringSetting(_passcodeKey, code);
  }

  Future<void> disablePasscode() async {
    state = state.copyWith(passcodeLockEnabled: false);
    await _storage.deleteSetting(_passcodeKey);
  }

  Future<bool> verifyPasscode(String code) async {
    final savedCode = await _storage.readStringSetting(_passcodeKey);
    return savedCode != null && savedCode == code;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    await _storage.writeIntSetting(_autoLockMinutesKey, minutes);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      return AppSettingsNotifier(ref.watch(storageProvider));
    });
