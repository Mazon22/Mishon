import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/constants/api_constants.dart';

String resolvePostAuthDestination({
  required AuthResponse response,
  required bool onboardingCompleted,
}) {
  if (ApiConstants.enableEmailVerificationFlow &&
      (response.requiresEmailVerification || !response.emailVerified)) {
    return '/verify-email/pending?email=${Uri.encodeComponent(response.email)}';
  }

  return onboardingCompleted ? '/feed' : '/onboarding';
}
