import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/features/profile/screens/profile_media_editor_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile initialProfile;

  const ProfileSetupScreen({super.key, required this.initialProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _picker = ImagePicker();
  final _usernameRegex = RegExp(r'^[a-z0-9._]{5,50}$');
  final _usernameFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    final sanitized = newValue.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  });

  late final TextEditingController _usernameController;
  late final TextEditingController _aboutController;

  Timer? _usernameDebounce;
  Future<bool>? _usernameAvailabilityFuture;
  String? _availabilityRequestUsername;
  bool? _availabilityResult;
  bool _isCheckingUsername = false;
  bool _isSaving = false;
  bool _isMediaBusy = false;

  Uint8List? _avatarBytes;
  Uint8List? _bannerBytes;
  late double _avatarScale;
  late double _avatarOffsetX;
  late double _avatarOffsetY;
  late double _bannerScale;
  late double _bannerOffsetX;
  late double _bannerOffsetY;
  bool _removeAvatar = false;
  bool _removeBanner = false;
  bool _avatarDirty = false;
  bool _bannerDirty = false;

  String get _initialUsername => widget.initialProfile.username.trim().toLowerCase();
  String get _initialAbout => (widget.initialProfile.aboutMe ?? '').trim();
  String get _username => _usernameController.text.trim().toLowerCase();
  String get _about => _aboutController.text.trim();

  bool get _isUsernameLocallyValid => _usernameRegex.hasMatch(_username);
  bool get _hasPendingChanges =>
      _username != _initialUsername ||
      _about != _initialAbout ||
      _avatarDirty ||
      _bannerDirty;
  bool get _isUsernameReadyToSave {
    if (!_isUsernameLocallyValid) {
      return false;
    }

    if (_username == _initialUsername) {
      return true;
    }

    return !_isCheckingUsername &&
        _availabilityRequestUsername == _username &&
        _availabilityResult == true;
  }

  bool get _canSave =>
      !_isSaving && !_isMediaBusy && _isUsernameReadyToSave && _hasPendingChanges;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: _initialUsername);
    _aboutController = TextEditingController(text: widget.initialProfile.aboutMe ?? '');
    _avatarScale = widget.initialProfile.avatarScale;
    _avatarOffsetX = widget.initialProfile.avatarOffsetX;
    _avatarOffsetY = widget.initialProfile.avatarOffsetY;
    _bannerScale = widget.initialProfile.bannerScale;
    _bannerOffsetX = widget.initialProfile.bannerOffsetX;
    _bannerOffsetY = widget.initialProfile.bannerOffsetY;
    _availabilityRequestUsername = _initialUsername;
    _availabilityResult = true;
    _usernameAvailabilityFuture = Future<bool>.value(true);
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _availabilityResult = null;
      _isCheckingUsername = false;
    });

    if (_username.isEmpty || !_isUsernameLocallyValid) {
      return;
    }

    if (_username == _initialUsername) {
      setState(() {
        _availabilityRequestUsername = _username;
        _availabilityResult = true;
        _usernameAvailabilityFuture = Future<bool>.value(true);
      });
      return;
    }

    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      final requestedUsername = _username;
      final future = ref
          .read(authRepositoryProvider)
          .checkUsernameAvailability(requestedUsername);

      setState(() {
        _availabilityRequestUsername = requestedUsername;
        _usernameAvailabilityFuture = future;
      });

      future.then((available) {
        if (!mounted || _username != requestedUsername) {
          return;
        }

        setState(() {
          _availabilityResult = available;
          _isCheckingUsername = false;
        });
      }).catchError((_) {
        if (!mounted || _username != requestedUsername) {
          return;
        }

        setState(() {
          _availabilityResult = null;
          _isCheckingUsername = false;
        });
      });
    });
  }

  Future<void> _editMedia(ProfileMediaKind kind) async {
    if (_isMediaBusy || _isSaving) {
      return;
    }

    setState(() => _isMediaBusy = true);

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (image == null || !mounted) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }

      final result = await Navigator.of(context).push<ProfileMediaEditResult>(
        MaterialPageRoute(
          builder: (_) => ProfileMediaEditorScreen(
            imageBytes: bytes,
            kind: kind,
            initialScale: kind == ProfileMediaKind.avatar ? _avatarScale : _bannerScale,
            initialOffsetX: kind == ProfileMediaKind.avatar ? _avatarOffsetX : _bannerOffsetX,
            initialOffsetY: kind == ProfileMediaKind.avatar ? _avatarOffsetY : _bannerOffsetY,
          ),
        ),
      );

      if (result == null || !mounted) {
        return;
      }

      setState(() {
        if (kind == ProfileMediaKind.avatar) {
          _avatarBytes = result.bytes;
          _avatarScale = result.scale;
          _avatarOffsetX = result.offsetX;
          _avatarOffsetY = result.offsetY;
          _removeAvatar = false;
          _avatarDirty = true;
        } else {
          _bannerBytes = result.bytes;
          _bannerScale = result.scale;
          _bannerOffsetX = result.offsetX;
          _bannerOffsetY = result.offsetY;
          _removeBanner = false;
          _bannerDirty = true;
        }
      });
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotPrepareImage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMediaBusy = false);
      }
    }
  }

  void _removeSelectedMedia(ProfileMediaKind kind) {
    setState(() {
      if (kind == ProfileMediaKind.avatar) {
        _avatarBytes = null;
        _removeAvatar = true;
        _avatarDirty = true;
        _avatarScale = 1;
        _avatarOffsetX = 0;
        _avatarOffsetY = 0;
      } else {
        _bannerBytes = null;
        _removeBanner = true;
        _bannerDirty = true;
        _bannerScale = 1;
        _bannerOffsetX = 0;
        _bannerOffsetY = 0;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      var updatedProfile = widget.initialProfile;

      if (_avatarDirty || _bannerDirty) {
        updatedProfile = await repository.updateProfileMedia(
          avatarBytes: _removeAvatar ? null : _avatarBytes,
          bannerBytes: _removeBanner ? null : _bannerBytes,
          avatarScale: _avatarScale,
          avatarOffsetX: _avatarOffsetX,
          avatarOffsetY: _avatarOffsetY,
          bannerScale: _bannerScale,
          bannerOffsetX: _bannerOffsetX,
          bannerOffsetY: _bannerOffsetY,
          removeAvatar: _removeAvatar,
          removeBanner: _removeBanner,
        );
      }

      if (_username != _initialUsername || _about != _initialAbout) {
        updatedProfile = await repository.updateProfile(
          username: _username,
          aboutMe: _about,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedProfile);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotSaveProfile, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD14343) : const Color(0xFF1F8F52),
      ),
    );
  }

  Color get _usernameStatusColor {
    if (_username.isEmpty) {
      return const Color(0xFFE3E8F2);
    }
    if (!_isUsernameLocallyValid) {
      return const Color(0xFFF3D2D2);
    }
    if (_availabilityResult == true) {
      return const Color(0xFFD7F0DF);
    }
    if (_availabilityResult == false) {
      return const Color(0xFFF3D2D2);
    }
    return const Color(0xFFE3E8F2);
  }

  Widget _buildUsernameStatus() {
    final strings = AppStrings.of(context);

    if (_username.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('username-empty'));
    }

    if (_username.length < 5) {
      return _UsernameStatusText(
        key: const ValueKey('username-short'),
        message: strings.usernameMinLength,
        color: const Color(0xFFD14343),
      );
    }

    if (!_isUsernameLocallyValid) {
      return _UsernameStatusText(
        key: const ValueKey('username-invalid'),
        message: strings.usernameInvalid,
        color: const Color(0xFFD14343),
      );
    }

    if (_isCheckingUsername) {
      return _UsernameStatusText(
        key: const ValueKey('username-checking'),
        message: strings.checkingUsername,
        color: const Color(0xFF6A7890),
      );
    }

    return FutureBuilder<bool>(
      key: ValueKey('username-${_availabilityRequestUsername ?? 'none'}'),
      future: _usernameAvailabilityFuture,
      builder: (context, snapshot) {
        if (_username == _initialUsername) {
          return _UsernameStatusText(
            message: strings.usernameAvailable,
            color: const Color(0xFF1F8F52),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _UsernameStatusText(
            message: strings.checkingUsername,
            color: const Color(0xFF6A7890),
          );
        }

        if (snapshot.hasError) {
          return _UsernameStatusText(
            message: strings.usernameVerifyFailed,
            color: const Color(0xFFD28A2E),
          );
        }

        if (snapshot.data == true) {
          return _UsernameStatusText(
            message: strings.usernameAvailable,
            color: const Color(0xFF1F8F52),
          );
        }

        return _UsernameStatusText(
          message: strings.usernameUnavailable,
          color: const Color(0xFFD14343),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final currentAvatarUrl = _removeAvatar ? null : widget.initialProfile.avatarUrl;
    final currentBannerUrl = _removeBanner ? null : widget.initialProfile.bannerUrl;
    final hasAvatar = (_avatarDirty && !_removeAvatar) || (widget.initialProfile.avatarUrl?.isNotEmpty ?? false);
    final hasBanner = (_bannerDirty && !_removeBanner) || (widget.initialProfile.bannerUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(strings.profileSetupTitle),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileSetupHeader(
                    username: _username.isEmpty ? widget.initialProfile.username : _username,
                    avatarUrl: currentAvatarUrl,
                    avatarBytes: _removeAvatar ? null : _avatarBytes,
                    avatarScale: _avatarScale,
                    avatarOffsetX: _avatarOffsetX,
                    avatarOffsetY: _avatarOffsetY,
                    bannerUrl: currentBannerUrl,
                    bannerBytes: _removeBanner ? null : _bannerBytes,
                    bannerScale: _bannerScale,
                    bannerOffsetX: _bannerOffsetX,
                    bannerOffsetY: _bannerOffsetY,
                    isBusy: _isMediaBusy || _isSaving,
                    onChangeAvatar: () => _editMedia(ProfileMediaKind.avatar),
                    onChangeBanner: () => _editMedia(ProfileMediaKind.banner),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    strings.profileSetupSectionTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C2738),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.profileSetupSectionSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF69788F),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FieldCard(
                    label: strings.username,
                    accent: _usernameStatusColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          autofocus: true,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                            _usernameFormatter,
                          ],
                          decoration: InputDecoration(
                            prefixText: '@',
                            hintText: strings.usernameHint,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _buildUsernameStatus(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldCard(
                    label: strings.about,
                    accent: const Color(0xFFCFD7E6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _aboutController,
                          minLines: 4,
                          maxLines: 6,
                          maxLength: 160,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(160),
                          ],
                          decoration: InputDecoration(
                            hintText: strings.aboutHint,
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: const Color(0xFF1C2738),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_aboutController.text.characters.length}/160',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8A97AB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ProfileQuickAction(
                        icon: Icons.add_a_photo_outlined,
                        label: strings.changeAvatar,
                        onTap: _isMediaBusy || _isSaving
                            ? null
                            : () => _editMedia(ProfileMediaKind.avatar),
                      ),
                      _ProfileQuickAction(
                        icon: Icons.hide_image_outlined,
                        label: strings.removeAvatar,
                        onTap: (_isMediaBusy || _isSaving || (!hasAvatar) || _removeAvatar)
                            ? null
                            : () => _removeSelectedMedia(ProfileMediaKind.avatar),
                      ),
                      _ProfileQuickAction(
                        icon: Icons.wallpaper_outlined,
                        label: strings.changeBanner,
                        onTap: _isMediaBusy || _isSaving
                            ? null
                            : () => _editMedia(ProfileMediaKind.banner),
                      ),
                      _ProfileQuickAction(
                        icon: Icons.layers_clear_outlined,
                        label: strings.removeBanner,
                        onTap: (_isMediaBusy || _isSaving || (!hasBanner) || _removeBanner)
                            ? null
                            : () => _removeSelectedMedia(ProfileMediaKind.banner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(strings.cancel),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton(
                          onPressed: _canSave ? _save : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(_isSaving ? strings.saving : strings.save),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSetupHeader extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final String? bannerUrl;
  final Uint8List? bannerBytes;
  final double bannerScale;
  final double bannerOffsetX;
  final double bannerOffsetY;
  final bool isBusy;
  final VoidCallback onChangeAvatar;
  final VoidCallback onChangeBanner;

  const _ProfileSetupHeader({
    required this.username,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.avatarScale,
    required this.avatarOffsetX,
    required this.avatarOffsetY,
    required this.bannerUrl,
    required this.bannerBytes,
    required this.bannerScale,
    required this.bannerOffsetX,
    required this.bannerOffsetY,
    required this.isBusy,
    required this.onChangeAvatar,
    required this.onChangeBanner,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final fallbackName = username.isEmpty ? 'Mishon' : username;
    const avatarSize = 104.0;
    const avatarTop = 168.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13203B).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: avatarTop + avatarSize,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: MouseRegion(
                    cursor: isBusy
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: isBusy ? null : onChangeBanner,
                      child: _BannerPreview(
                        username: fallbackName,
                        imageUrl: bannerUrl,
                        imageBytes: bannerBytes,
                        scale: bannerScale,
                        offsetX: bannerOffsetX,
                        offsetY: bannerOffsetY,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: avatarTop + 14,
                  child: FilledButton.tonalIcon(
                    onPressed: isBusy ? null : onChangeBanner,
                    icon: const Icon(Icons.wallpaper_outlined, size: 18),
                    label: Text(strings.changeBanner),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: avatarTop,
                  child: MouseRegion(
                    cursor: isBusy
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: isBusy ? null : onChangeAvatar,
                      child: SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10203D).withValues(alpha: 0.14),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: _AvatarPreview(
                                username: fallbackName,
                                imageUrl: avatarUrl,
                                imageBytes: avatarBytes,
                                scale: avatarScale,
                                offsetX: avatarOffsetX,
                                offsetY: avatarOffsetY,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: 4,
                              child: Material(
                                color: const Color(0xFF2A5BFF),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: isBusy ? null : onChangeAvatar,
                                  customBorder: const CircleBorder(),
                                  child: const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Color accent;

  const _FieldCard({
    required this.label,
    required this.child,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF6A7890),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ProfileQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide(
          color: const Color(0xFFD7DFF0).withValues(alpha: onTap == null ? 0.5 : 1),
        ),
      ),
    );
  }
}

class _UsernameStatusText extends StatelessWidget {
  final String message;
  final Color color;

  const _UsernameStatusText({
    super.key,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BannerPreview extends StatelessWidget {
  final String username;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double scale;
  final double offsetX;
  final double offsetY;

  const _BannerPreview({
    required this.username,
    required this.imageUrl,
    required this.imageBytes,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 212,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF10203D),
                    Color(0xFF2A5BFF),
                    Color(0xFFFF9A64),
                  ],
                ),
              ),
            ),
            _EditableMediaViewport(
              imageUrl: imageUrl,
              imageBytes: imageBytes,
              scale: scale,
              offsetX: offsetX,
              offsetY: offsetY,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    const Color(0xFF081226).withValues(alpha: 0.36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String username;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double scale;
  final double offsetX;
  final double offsetY;

  const _AvatarPreview({
    required this.username,
    required this.imageUrl,
    required this.imageBytes,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) {
      return AppAvatar(
        username: username,
        imageUrl: imageUrl,
        size: 96,
        scale: scale,
        offsetX: offsetX,
        offsetY: offsetY,
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 96,
        height: 96,
        child: _EditableMediaViewport(
          imageBytes: imageBytes,
          scale: scale,
          offsetX: offsetX,
          offsetY: offsetY,
        ),
      ),
    );
  }
}

class _EditableMediaViewport extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double scale;
  final double offsetX;
  final double offsetY;

  const _EditableMediaViewport({
    this.imageUrl,
    this.imageBytes,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null && (imageUrl == null || imageUrl!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dx = constraints.maxWidth * 0.35 * offsetX;
        final dy = constraints.maxHeight * 0.35 * offsetY;

        final image = imageBytes != null
            ? Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: image,
            ),
          ),
        );
      },
    );
  }
}
