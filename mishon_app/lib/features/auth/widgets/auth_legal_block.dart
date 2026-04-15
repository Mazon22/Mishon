import 'package:flutter/material.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/features/auth/widgets/auth_legal_sheet.dart';

class AuthLegalBlock extends StatelessWidget {
  const AuthLegalBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 2,
          children: [
            Text(
              '${strings.legalLead} ',
              textAlign: TextAlign.center,
              style: textStyle,
            ),
            _AuthLegalLink(
              label: strings.legalTermsLink,
              onTap:
                  () =>
                      showAuthLegalSheet(context, AuthLegalDocumentType.terms),
            ),
            Text(', ', style: textStyle),
            _AuthLegalLink(
              label: strings.legalPrivacyLink,
              onTap:
                  () => showAuthLegalSheet(
                    context,
                    AuthLegalDocumentType.privacy,
                  ),
            ),
            Text(' ${strings.legalAnd} ', style: textStyle),
            _AuthLegalLink(
              label: strings.legalCookieLink,
              onTap:
                  () =>
                      showAuthLegalSheet(context, AuthLegalDocumentType.cookie),
            ),
            Text('.', style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _AuthLegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AuthLegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
