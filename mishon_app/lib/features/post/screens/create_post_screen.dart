import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/minimal_components.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

import '../providers/create_post_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final strings = AppStrings.of(context);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFile = kIsWeb ? null : File(image.path);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      showAppToast(
        context,
        message:
            strings.isRu
                ? 'Не удалось выбрать фотографию'
                : 'Could not pick the image',
        isError: true,
      );
    }
  }

  Future<void> _createPost() async {
    final strings = AppStrings.of(context);
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _errorMessage =
            strings.isRu
                ? 'Напишите что-нибудь перед публикацией'
                : 'Write something before posting';
      });
      return;
    }

    if (content.length > 1000) {
      setState(() {
        _errorMessage =
            strings.isRu ? 'Максимум 1000 символов' : 'Maximum 1000 characters';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final success = await ref
        .read(createPostNotifierProvider.notifier)
        .createPost(content, _selectedImageBytes);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (success) {
      ref.invalidate(feedNotifierProvider(FeedTabType.forYou));
      ref.invalidate(feedNotifierProvider(FeedTabType.following));
      HapticFeedback.lightImpact();
      context.go('/feed');
      return;
    }

    final state = ref.read(createPostNotifierProvider);
    setState(() {
      _errorMessage = state.when(
        data:
            (_) =>
                strings.isRu
                    ? 'Не удалось опубликовать пост'
                    : 'Could not publish the post',
        error:
            (error, _) =>
                error is String
                    ? error
                    : (strings.isRu
                        ? 'Не удалось опубликовать пост'
                        : 'Could not publish the post'),
        loading: () => null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentProfile = ref.watch(profileNotifierProvider).valueOrNull;
    final draftLength = _contentController.text.characters.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF3F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/feed'),
        ),
        title: Text(strings.createPost),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: strings.isRu ? 'Опубликовать' : 'Publish',
              onPressed: _createPost,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF2EEFF), Color(0xFFEAF5FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -40,
              child: _CreatePostOrb(
                size: 220,
                colors: [
                  const Color(0xFFBFD5FF).withValues(alpha: 0.7),
                  const Color(0x00BFD5FF),
                ],
              ),
            ),
            Positioned(
              right: -70,
              top: 180,
              child: _CreatePostOrb(
                size: 240,
                colors: [
                  const Color(0xFFDCCEFF).withValues(alpha: 0.68),
                  const Color(0x00DCCEFF),
                ],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    _CreatePostProfileCard(
                      strings: strings,
                      currentProfile: currentProfile,
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFFD6DB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFD1465A),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB5384A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF132443,
                                ).withValues(alpha: 0.08),
                                blurRadius: 30,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _CreatePostTag(
                                    label:
                                        strings.isRu
                                            ? 'Текст поста'
                                            : 'Post text',
                                  ),
                                  const Spacer(),
                                  _CreatePostCounter(length: draftLength),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _contentController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText:
                                      strings.isRu
                                          ? 'Что нового сегодня?'
                                          : 'What is new today?',
                                  hintText:
                                      strings.isRu
                                          ? 'Напишите пост для ленты...'
                                          : 'Write a post for the feed...',
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF18243C),
                                  height: 1.5,
                                ),
                                maxLines: 8,
                                maxLength: 1000,
                                buildCounter:
                                    (
                                      context, {
                                      required currentLength,
                                      required isFocused,
                                      required maxLength,
                                    }) => const SizedBox.shrink(),
                                enabled: !_isSubmitting,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImageFile != null ||
                        _selectedImageBytes != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child:
                                kIsWeb
                                    ? Image.memory(
                                      _selectedImageBytes!,
                                      height: 240,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _brokenPreview(),
                                    )
                                    : Image.file(
                                      _selectedImageFile!,
                                      height: 240,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _brokenPreview(),
                                    ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton(
                              onPressed:
                                  () => setState(() {
                                    _selectedImageBytes = null;
                                    _selectedImageFile = null;
                                  }),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3A72FF,
                                  ).withValues(alpha: 0.16),
                                  blurRadius: 20,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: _isSubmitting ? null : _pickImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                backgroundColor: const Color(0xFF2F67FF),
                                foregroundColor: Colors.white,
                              ),
                              label: Text(
                                strings.isRu ? 'Добавить фото' : 'Add photo',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFD9E3F4)),
                          ),
                          child: IconButton(
                            onPressed: _isSubmitting ? null : _createPost,
                            tooltip: strings.isRu ? 'Опубликовать' : 'Publish',
                            icon: const Icon(Icons.arrow_upward_rounded),
                            color: const Color(0xFF2F67FF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brokenPreview() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
      ),
    );
  }
}

class _CreatePostProfileCard extends StatelessWidget {
  final AppStrings strings;
  final dynamic currentProfile;

  const _CreatePostProfileCard({
    required this.strings,
    required this.currentProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF122746).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFBCD4FF), Color(0xFFE0D7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F67FF).withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AppAvatar(
              username: currentProfile?.username ?? 'You',
              imageUrl: currentProfile?.avatarUrl,
              size: 52,
              scale: currentProfile?.avatarScale ?? 1,
              offsetX: currentProfile?.avatarOffsetX ?? 0,
              offsetY: currentProfile?.avatarOffsetY ?? 0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CreatePostTag(
                  label: strings.isRu ? 'Новый пост' : 'New post',
                  foreground: const Color(0xFF2F67FF),
                  background: const Color(0xFFEAF1FF),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentProfile?.username ??
                          (strings.isRu ? 'Ваш пост' : 'Your post'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF18243C),
                      ),
                    ),
                    if (currentProfile != null) ...[
                      const SizedBox(width: 6),
                      const AppVerifiedBadge(size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  strings.isRu
                      ? 'Поделитесь мыслью, на которой хочется задержаться.'
                      : 'Share something worth stopping the scroll for.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF66758E),
                    height: 1.35,
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

class _CreatePostTag extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _CreatePostTag({
    required this.label,
    this.foreground = const Color(0xFF5672AE),
    this.background = const Color(0xFFF1F5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _CreatePostCounter extends StatelessWidget {
  final int length;

  const _CreatePostCounter({required this.length});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E9F6)),
      ),
      child: Text(
        '$length/1000',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF73819A),
        ),
      ),
    );
  }
}

class _CreatePostOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _CreatePostOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
