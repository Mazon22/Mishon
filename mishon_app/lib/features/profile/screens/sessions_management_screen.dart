import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/states.dart';

class SessionsManagementScreen extends ConsumerStatefulWidget {
  const SessionsManagementScreen({super.key});

  @override
  ConsumerState<SessionsManagementScreen> createState() =>
      _SessionsManagementScreenState();
}

class _SessionsManagementScreenState
    extends ConsumerState<SessionsManagementScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  List<SessionModel> _sessions = const [];

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
      final sessions = await ref.read(authRepositoryProvider).getSessions();
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
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

  Future<void> _revokeSession(SessionModel session) async {
    final strings = AppStrings.of(context);
    if (session.isCurrent) {
      showAppToast(
        context,
        message: strings.currentSessionCannotBeRevoked,
        isError: true,
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      await _load();
      if (!mounted) {
        return;
      }
      showAppToast(context, message: strings.sessionRevoked);
    } catch (error) {
      showAppToast(context, message: error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _logoutOtherSessions() async {
    final others = _sessions.where((session) => !session.isCurrent).toList();
    if (others.isEmpty) {
      showAppToast(
        context,
        message: AppStrings.of(context).noOtherSessions,
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      for (final session in others) {
        await ref.read(authRepositoryProvider).revokeSession(session.id);
      }
      await _load();
      if (!mounted) {
        return;
      }
      showAppToast(context, message: AppStrings.of(context).otherSessionsLoggedOut);
    } catch (error) {
      showAppToast(context, message: error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _logoutAllSessions() async {
    setState(() => _isBusy = true);
    try {
      await ref.read(authRepositoryProvider).logoutAllSessions();
      ref.read(appBootstrapProvider.notifier).handleLoggedOut();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } catch (error) {
      showAppToast(context, message: error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.activeSessionsTitle)),
      body:
          _isLoading
              ? const LoadingState()
              : _errorMessage != null
              ? ErrorState(message: _errorMessage!, onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _isBusy ? null : _logoutOtherSessions,
                            child: Text(strings.logoutOtherSessions),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isBusy ? null : _logoutAllSessions,
                            child: Text(strings.logoutAllSessionsAction),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._sessions.map((session) => _buildSessionCard(strings, session)),
                  ],
                ),
              ),
    );
  }

  Widget _buildSessionCard(AppStrings strings, SessionModel session) {
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
          Row(
            children: [
              const Icon(Icons.devices_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session.deviceName?.trim().isNotEmpty == true
                      ? session.deviceName!
                      : strings.unknownDevice,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (session.isCurrent)
                Chip(label: Text(strings.currentSessionChip)),
            ],
          ),
          const SizedBox(height: 12),
          _FactRow(
            label: strings.platformLabel,
            value: session.platform ?? strings.unknownPlatform,
          ),
          _FactRow(
            label: strings.lastUsedLabel,
            value: _formatDate(session.lastUsedAt),
          ),
          _FactRow(
            label: strings.signedInLabel,
            value: _formatDate(session.createdAt),
          ),
          _FactRow(
            label: strings.sessionExpiresLabel,
            value: _formatDate(session.expiresAt),
          ),
          if (session.ipAddress != null && session.ipAddress!.isNotEmpty)
            _FactRow(label: strings.ipAddressLabel, value: session.ipAddress!),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _isBusy || session.isCurrent ? null : () => _revokeSession(session),
              child: Text(
                session.isCurrent
                    ? strings.currentSessionChip
                    : strings.revokeSessionAction,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM, HH:mm').format(value.toLocal());
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C6B80)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
