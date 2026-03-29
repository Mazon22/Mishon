import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/states.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  PrivacySettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await ref.read(authRepositoryProvider).getPrivacySettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updatePrivacySettings(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = updated;
        _isSaving = false;
      });
      showAppToast(context, message: AppStrings.of(context).privacySaved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      showAppToast(context, message: error.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.privacyTitle),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingState()
              : _errorMessage != null || _settings == null
              ? ErrorState(message: _errorMessage ?? strings.operationError, onRetry: _load)
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  SwitchListTile.adaptive(
                    value: _settings!.isPrivateAccount,
                    title: Text(strings.privateAccountTitle),
                    subtitle: Text(strings.privateAccountSubtitle),
                    onChanged:
                        (value) => setState(
                          () => _settings = PrivacySettings(
                            isPrivateAccount: value,
                            profileVisibility: _settings!.profileVisibility,
                            messagePrivacy: _settings!.messagePrivacy,
                            commentPrivacy: _settings!.commentPrivacy,
                            presenceVisibility: _settings!.presenceVisibility,
                          ),
                        ),
                  ),
                  _PrivacyDropdown(
                    title: strings.profileVisibilityTitle,
                    subtitle: strings.profileVisibilitySubtitle,
                    value: _settings!.profileVisibility,
                    items: _profileVisibilityItems(strings),
                    onChanged:
                        (value) => setState(
                          () => _settings = PrivacySettings(
                            isPrivateAccount: _settings!.isPrivateAccount,
                            profileVisibility: value,
                            messagePrivacy: _settings!.messagePrivacy,
                            commentPrivacy: _settings!.commentPrivacy,
                            presenceVisibility: _settings!.presenceVisibility,
                          ),
                        ),
                  ),
                  _PrivacyDropdown(
                    title: strings.messagePrivacyTitle,
                    subtitle: strings.messagePrivacySubtitle,
                    value: _settings!.messagePrivacy,
                    items: _commonAudienceItems(strings),
                    onChanged:
                        (value) => setState(
                          () => _settings = PrivacySettings(
                            isPrivateAccount: _settings!.isPrivateAccount,
                            profileVisibility: _settings!.profileVisibility,
                            messagePrivacy: value,
                            commentPrivacy: _settings!.commentPrivacy,
                            presenceVisibility: _settings!.presenceVisibility,
                          ),
                        ),
                  ),
                  _PrivacyDropdown(
                    title: strings.commentPrivacyTitle,
                    subtitle: strings.commentPrivacySubtitle,
                    value: _settings!.commentPrivacy,
                    items: _commonAudienceItems(strings),
                    onChanged:
                        (value) => setState(
                          () => _settings = PrivacySettings(
                            isPrivateAccount: _settings!.isPrivateAccount,
                            profileVisibility: _settings!.profileVisibility,
                            messagePrivacy: _settings!.messagePrivacy,
                            commentPrivacy: value,
                            presenceVisibility: _settings!.presenceVisibility,
                          ),
                        ),
                  ),
                  _PrivacyDropdown(
                    title: strings.presencePrivacyTitle,
                    subtitle: strings.presencePrivacySubtitle,
                    value: _settings!.presenceVisibility,
                    items: _commonAudienceItems(strings),
                    onChanged:
                        (value) => setState(
                          () => _settings = PrivacySettings(
                            isPrivateAccount: _settings!.isPrivateAccount,
                            profileVisibility: _settings!.profileVisibility,
                            messagePrivacy: _settings!.messagePrivacy,
                            commentPrivacy: _settings!.commentPrivacy,
                            presenceVisibility: value,
                          ),
                        ),
                  ),
                ],
              ),
    );
  }

  Map<String, String> _profileVisibilityItems(AppStrings strings) {
    return <String, String>{
      'Public': strings.privacyAudiencePublic,
      'FollowersOnly': strings.privacyAudienceFollowers,
      'Private': strings.privacyAudienceNobody,
    };
  }

  Map<String, String> _commonAudienceItems(AppStrings strings) {
    return <String, String>{
      'Everyone': strings.privacyAudienceEveryone,
      'Followers': strings.privacyAudienceFollowers,
      'Friends': strings.privacyAudienceFriends,
      'Nobody': strings.privacyAudienceNobody,
    };
  }
}

class _PrivacyDropdown extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _PrivacyDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C6B80)),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: value,
            items:
                items.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
            onChanged: (nextValue) {
              if (nextValue != null) {
                onChanged(nextValue);
              }
            },
          ),
        ],
      ),
    );
  }
}
