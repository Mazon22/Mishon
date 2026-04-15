import 'package:flutter/material.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';

class AuthSocialSection extends StatelessWidget {
  const AuthSocialSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSocialButton(
          label: strings.continueWithGoogle,
          icon: const GoogleBrandIcon(),
          onTap: () => showSocialAuthPlaceholder(context, 'Google'),
        ),
        const SizedBox(height: 10),
        AuthSocialButton(
          label: strings.continueWithApple,
          icon: const AppleBrandIcon(),
          onTap: () => showSocialAuthPlaceholder(context, 'Apple'),
        ),
        const SizedBox(height: 14),
        AuthDivider(text: strings.orDivider),
        const SizedBox(height: 14),
      ],
    );
  }
}
