import 'package:flutter/material.dart';

import 'package:mishon_app/core/localization/app_strings.dart';

class ReportDraft {
  final String reason;
  final String? note;

  const ReportDraft({
    required this.reason,
    required this.note,
  });
}

Future<ReportDraft?> showReportDialog(
  BuildContext context, {
  required String title,
}) async {
  final strings = AppStrings.of(context);
  final noteController = TextEditingController();
  var selectedReason = 'Spam';

  final result = await showModalBottomSheet<ReportDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      labelText: strings.reportReasonLabel,
                    ),
                    items:
                        _reasonOptions(strings)
                            .entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedReason = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: strings.reportNoteLabel,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(strings.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              () => Navigator.of(context).pop(
                                ReportDraft(
                                  reason: selectedReason,
                                  note:
                                      noteController.text.trim().isEmpty
                                          ? null
                                          : noteController.text.trim(),
                                ),
                              ),
                          child: Text(strings.reportAction),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  noteController.dispose();
  return result;
}

Map<String, String> _reasonOptions(AppStrings strings) {
  return <String, String>{
    'Spam': strings.reasonSpam,
    'Harassment': strings.reasonHarassment,
    'HateSpeech': strings.reasonHateSpeech,
    'Violence': strings.reasonViolence,
    'Nudity': strings.reasonNudity,
    'Scam': strings.reasonScam,
    'Impersonation': strings.reasonImpersonation,
    'SelfHarm': strings.reasonSelfHarm,
    'PrivacyViolation': strings.reasonPrivacyViolation,
    'IllegalContent': strings.reasonIllegalContent,
    'SuspiciousActivity': strings.reasonSuspiciousActivity,
    'Other': strings.reasonOther,
  };
}
