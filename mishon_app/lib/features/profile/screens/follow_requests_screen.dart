import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';

class FollowRequestsScreen extends ConsumerStatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  ConsumerState<FollowRequestsScreen> createState() =>
      _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends ConsumerState<FollowRequestsScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  List<FriendRequestModel> _requests = const [];

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
      final requests = await ref
          .read(socialRepositoryProvider)
          .getIncomingFollowRequests(forceRefresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
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

  Future<void> _handleRequest(
    FriendRequestModel request,
    bool approve,
  ) async {
    setState(() => _isBusy = true);
    try {
      if (approve) {
        await ref.read(socialRepositoryProvider).approveFollowRequest(request.id);
      } else {
        await ref.read(socialRepositoryProvider).rejectFollowRequest(request.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _requests =
            _requests.where((item) => item.id != request.id).toList(growable: false);
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.followRequestsTitle)),
      body:
          _isLoading
              ? const LoadingState()
              : _errorMessage != null
              ? ErrorState(message: _errorMessage!, onRetry: _load)
              : _requests.isEmpty
              ? EmptyState(
                icon: Icons.lock_person_outlined,
                title: strings.noFollowRequestsTitle,
                subtitle: strings.noFollowRequestsSubtitle,
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCE4F2)),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            username: request.username,
                            imageUrl: request.avatarUrl,
                            size: 52,
                            scale: request.avatarScale,
                            offsetX: request.avatarOffsetX,
                            offsetY: request.avatarOffsetY,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: InkWell(
                              onTap: () => context.push('/profile/${request.userId}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.username,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (request.aboutMe ?? '').trim().isEmpty
                                        ? strings.followRequestDefaultHint
                                        : request.aboutMe!.trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF5C6B80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              FilledButton.tonal(
                                onPressed: _isBusy ? null : () => _handleRequest(request, true),
                                child: Text(strings.approveAction),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isBusy ? null : () => _handleRequest(request, false),
                                child: Text(strings.rejectAction),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemCount: _requests.length,
                ),
              ),
    );
  }
}
