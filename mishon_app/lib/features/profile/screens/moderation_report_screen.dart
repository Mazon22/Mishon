part of 'profile_settings_screen.dart';

class ModerationDashboardScreen extends ConsumerStatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  ConsumerState<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState
    extends ConsumerState<ModerationDashboardScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  UserProfile? _profile;
  List<ReportItemModel> _reports = const [];
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final socialRepository = ref.read(socialRepositoryProvider);
      final profile = await authRepository.getProfile(forceRefresh: true);
      final response = await socialRepository.getReportsPage(
        page: initial ? 1 : _page,
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _reports =
            initial
                ? response.items
                : <ReportItemModel>[..._reports, ...response.items];
        _page = response.page + 1;
        _hasMore = response.hasNext;
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

  Future<void> _openReport(ReportItemModel report) async {
    final detail = await ref.read(socialRepositoryProvider).getReport(report.id);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.of(context).moderationTitle,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFF6A7B91),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: AppStrings.of(context).cancel,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Text(
                        AppStrings.of(context).moderationCardSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6A7B91),
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '#${detail.id} · ${detail.reason}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        detail.customNote ?? AppStrings.of(context).noModeratorNote,
                      ),
                      const SizedBox(height: 16),
                      Text('${AppStrings.of(context).statusLabel}: ${detail.status}'),
                      Text('${AppStrings.of(context).resolutionLabel}: ${detail.resolution}'),
                      Text(
                        '${AppStrings.of(context).targetLabel}: ${detail.targetType} #${detail.targetId}',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonal(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () => _assignToCurrentModerator(detail.id),
                            child: Text(AppStrings.of(context).assignToMeAction),
                          ),
                          FilledButton.tonal(
                            onPressed:
                                _isBusy ? null : () => _resolveReport(detail),
                            child: Text(AppStrings.of(context).resolveReportAction),
                          ),
                          if (detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () => _warnUser(detail.targetUserId!, detail.id),
                              child: Text(AppStrings.of(context).warnUserAction),
                            ),
                          if (detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () => _suspendUser(detail.targetUserId!, detail.id),
                              child: Text(AppStrings.of(context).suspendUserAction),
                            ),
                          if (detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy ? null : () => _banUser(detail.targetUserId!, detail.id),
                              child: Text(AppStrings.of(context).banUserAction),
                            ),
                          if (_profile?.isAdmin == true && detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () => _assignModerator(detail.targetUserId!),
                              child: Text(AppStrings.of(context).assignModeratorAction),
                            ),
                          if (_profile?.isAdmin == true && detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () => _removeModerator(detail.targetUserId!),
                              child: Text(AppStrings.of(context).removeModeratorAction),
                            ),
                          if (_profile?.isAdmin == true && detail.targetUserId != null)
                            FilledButton.tonal(
                              onPressed:
                                  _isBusy
                                      ? null
                                      : () => _unbanUser(detail.targetUserId!, detail.id),
                              child: Text(AppStrings.of(context).unbanUserAction),
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
      },
    );
    await _load(initial: true);
  }

  Future<void> _assignToCurrentModerator(int reportId) async {
    final userId = _profile?.id;
    if (userId == null) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await ref.read(socialRepositoryProvider).assignReport(reportId, userId);
      if (mounted) {
        showAppToast(context, message: AppStrings.of(context).assignToMeAction);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _resolveReport(ReportDetailModel detail) async {
    final resolution = await _showResolutionDialog();
    if (resolution == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await ref.read(socialRepositoryProvider).resolveReport(
            detail.id,
            resolution: resolution.$1,
            resolutionNote: resolution.$2,
          );
      if (!mounted) {
        return;
      }
      showAppToast(context, message: AppStrings.of(context).resolveReportAction);
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _warnUser(int userId, int reportId) async {
    final note = await _showNoteDialog(AppStrings.of(context).warnUserAction);
    if (note == null || note.trim().isEmpty) {
      return;
    }
    await ref.read(socialRepositoryProvider).warnUser(userId, note, reportId: reportId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).warnUserAction);
    }
  }

  Future<void> _suspendUser(int userId, int reportId) async {
    final note = await _showNoteDialog(AppStrings.of(context).suspendUserAction);
    if (note == null || note.trim().isEmpty) {
      return;
    }
    await ref
        .read(socialRepositoryProvider)
        .suspendUser(userId, DateTime.now().add(const Duration(days: 7)), note, reportId: reportId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).suspendUserAction);
    }
  }

  Future<void> _banUser(int userId, int reportId) async {
    final note = await _showNoteDialog(AppStrings.of(context).banUserAction);
    if (note == null || note.trim().isEmpty) {
      return;
    }
    await ref.read(socialRepositoryProvider).banUser(userId, note, reportId: reportId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).banUserAction);
    }
  }

  Future<void> _unbanUser(int userId, int reportId) async {
    await ref.read(socialRepositoryProvider).unbanUser(userId, reportId: reportId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).unbanUserAction);
    }
  }

  Future<void> _assignModerator(int userId) async {
    await ref.read(socialRepositoryProvider).assignModerator(userId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).assignModeratorAction);
    }
  }

  Future<void> _removeModerator(int userId) async {
    await ref.read(socialRepositoryProvider).removeModerator(userId);
    if (mounted) {
      showAppToast(context, message: AppStrings.of(context).removeModeratorAction);
    }
  }

  Future<(String, String?)?> _showResolutionDialog() async {
    final strings = AppStrings.of(context);
    final noteController = TextEditingController();
    String resolution = 'WarningIssued';
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.resolveReportAction),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: resolution,
                    items: <MapEntry<String, String>>[
                      MapEntry('WarningIssued', strings.resolutionWarning),
                      MapEntry('ContentHidden', strings.resolutionContentHidden),
                      MapEntry('ContentRemoved', strings.resolutionContentRemoved),
                      MapEntry('UserSuspended', strings.resolutionUserSuspended),
                      MapEntry('UserBanned', strings.resolutionUserBanned),
                      MapEntry('Rejected', strings.resolutionRejected),
                    ]
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => resolution = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: strings.optionalModeratorNote,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(
                    (resolution, noteController.text.trim().isEmpty ? null : noteController.text.trim()),
                  ),
              child: Text(strings.save),
            ),
          ],
        );
      },
    );
    noteController.dispose();
    return result;
  }

  Future<String?> _showNoteDialog(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).optionalModeratorNote,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppStrings.of(context).save),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.moderationTitle)),
        body: const LoadingState(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.moderationTitle)),
        body: ErrorState(message: _errorMessage!, onRetry: () => _load(initial: true)),
      );
    }

    if (_profile == null || !_profile!.isModerator) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.moderationTitle)),
        body: EmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: strings.moderationUnavailableTitle,
          subtitle: strings.moderationUnavailableSubtitle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.moderationTitle)),
      body: RefreshIndicator(
        onRefresh: () => _load(initial: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (_reports.isEmpty)
              EmptyState(
                icon: Icons.fact_check_outlined,
                title: strings.noReportsTitle,
                subtitle: strings.noReportsSubtitle,
              )
            else
              ..._reports.map(
                (report) => Container(
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
                        '#${report.id} В· ${report.reason}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${report.targetType} #${report.targetId}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5C6B80),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${strings.statusLabel}: ${report.status}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5C6B80),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM, HH:mm').format(report.createdAt.toLocal()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _isBusy ? null : () => _openReport(report),
                            child: Text(strings.openReportDetails),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_hasMore)
              FilledButton.tonal(
                onPressed: _isBusy ? null : _load,
                child: Text(strings.loadMore),
              ),
          ],
        ),
      ),
    );
  }
}

