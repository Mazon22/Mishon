import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

class DeviceMetadata {
  final String deviceId;
  final String platformCode;
  final String deviceName;

  const DeviceMetadata({
    required this.deviceId,
    required this.platformCode,
    required this.deviceName,
  });

  // Backward-compatible alias used by existing repository/firebase flows.
  String get platform => platformCode;
}

Future<DeviceMetadata> resolveDeviceMetadata(SecureStorage storage) async {
  final deviceId =
      await storage.readStringSetting(SecureStorage.deviceIdKey) ??
      _generateDeviceId();
  await storage.writeStringSetting(SecureStorage.deviceIdKey, deviceId);

  return DeviceMetadata(
    deviceId: deviceId,
    platformCode: currentPlatformCode(),
    deviceName: currentDeviceName(),
  );
}

String currentPlatformCode() {
  if (kIsWeb) {
    return 'web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

String currentDeviceName() {
  if (kIsWeb) {
    return 'Web browser';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android device',
    TargetPlatform.iOS => 'iPhone or iPad',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows device',
    TargetPlatform.linux => 'Linux device',
    TargetPlatform.fuchsia => 'Fuchsia device',
  };
}

String _generateDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}
