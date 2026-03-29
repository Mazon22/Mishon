import 'dart:convert';

import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

DateTime? decodeJwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(normalized)),
    ) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is! num) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  } catch (_) {
    return null;
  }
}

DateTime resolveAccessTokenExpiry(AuthResponse response) {
  return response.accessTokenExpiresAt ??
      decodeJwtExpiry(response.token) ??
      DateTime.now().add(const Duration(minutes: 5));
}

Future<void> persistAuthResponse(
  SecureStorage storage,
  AuthResponse response,
) async {
  await storage.writeToken(response.token);
  await storage.writeUserId(response.userId);
  await storage.writeUsername(response.username);
  await storage.writeUserEmail(response.email);
  await storage.writeAccessTokenExpiry(resolveAccessTokenExpiry(response));
  await storage.writeEmailVerified(response.emailVerified);
  await storage.writeRole(response.role);

  if (response.sessionId != null && response.sessionId!.isNotEmpty) {
    await storage.writeSessionId(response.sessionId!);
  }

  if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
    await storage.writeRefreshToken(response.refreshToken!);
  }

  if (response.refreshTokenExpiry != null) {
    await storage.writeRefreshTokenExpiry(response.refreshTokenExpiry!);
  }
}
