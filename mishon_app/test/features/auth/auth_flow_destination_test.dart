import 'package:flutter_test/flutter_test.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/features/auth/auth_flow_destination.dart';

void main() {
  AuthResponse buildResponse({
    bool emailVerified = true,
    bool requiresEmailVerification = false,
  }) {
    return AuthResponse(
      userId: 1,
      username: 'michael',
      email: 'michael@example.com',
      token: 'token',
      accessTokenExpiresAt: DateTime(2025, 1, 1),
      emailVerified: emailVerified,
      requiresEmailVerification: requiresEmailVerification,
    );
  }

  test('routes unverified users to verify email pending', () {
    final route = resolvePostAuthDestination(
      response: buildResponse(
        emailVerified: false,
        requiresEmailVerification: true,
      ),
      onboardingCompleted: false,
    );

    expect(route, '/verify-email/pending?email=michael%40example.com');
  });

  test('routes verified users without onboarding to onboarding', () {
    final route = resolvePostAuthDestination(
      response: buildResponse(),
      onboardingCompleted: false,
    );

    expect(route, '/onboarding');
  });

  test('routes verified users with completed onboarding to feed', () {
    final route = resolvePostAuthDestination(
      response: buildResponse(),
      onboardingCompleted: true,
    );

    expect(route, '/feed');
  });
}
