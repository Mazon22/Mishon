import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick the image')),
      );
    }
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Write something before posting');
      return;
    }

    if (content.length > 1000) {
      setState(() => _errorMessage = 'Maximum 1000 characters');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final success = await ref.read(createPostNotifierProvider.notifier).createPost(
          content,
          _selectedImageBytes,
        );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (success) {
      ref.invalidate(feedNotifierProvider);
      context.go('/feed');
      return;
    }

    final state = ref.read(createPostNotifierProvider);
    setState(() {
      _errorMessage = state.when(
        data: (_) => 'Could not publish the post',
        error: (error, _) => error is String ? error : 'Could not publish the post',
        loading: () => null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = ref.watch(profileNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/feed'),
        ),
        title: const Text('New post'),
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
              onPressed: _createPost,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      username: currentProfile?.username ?? 'You',
                      imageUrl: currentProfile?.avatarUrl,
                      size: 52,
                      scale: currentProfile?.avatarScale ?? 1,
                      offsetX: currentProfile?.avatarOffsetX ?? 0,
                      offsetY: currentProfile?.avatarOffsetY ?? 0,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentProfile?.username ?? 'Your post',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share something worth stopping the scroll for.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'What is new today?',
                    hintText: 'Write a post for the feed...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  maxLength: 1000,
                  enabled: !_isSubmitting,
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedImageFile != null || _selectedImageBytes != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: kIsWeb
                          ? Image.memory(
                              _selectedImageBytes!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _brokenPreview(),
                            )
                          : Image.file(
                              _selectedImageFile!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _brokenPreview(),
                            ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: () => setState(() {
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
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Add photo'),
              ),
            ],
          ),
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
