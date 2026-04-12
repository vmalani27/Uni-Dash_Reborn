enum SyncUIPhase {
  idle,
  preparing,
  syncing,
  processing,
  ready,
  failed,
  timeout,
}

class SyncUIState {
  final SyncUIPhase phase;
  final String title;
  final String message;
  final String detail;
  final double progress;

  const SyncUIState({
    required this.phase,
    required this.title,
    required this.message,
    required this.detail,
    required this.progress,
  });

  bool get isActive =>
      phase == SyncUIPhase.preparing ||
      phase == SyncUIPhase.syncing ||
      phase == SyncUIPhase.processing;

  bool get isTerminal =>
      phase == SyncUIPhase.ready ||
      phase == SyncUIPhase.failed ||
      phase == SyncUIPhase.timeout;

  SyncUIState copyWith({
    SyncUIPhase? phase,
    String? title,
    String? message,
    String? detail,
    double? progress,
  }) {
    return SyncUIState(
      phase: phase ?? this.phase,
      title: title ?? this.title,
      message: message ?? this.message,
      detail: detail ?? this.detail,
      progress: progress ?? this.progress,
    );
  }

  factory SyncUIState.preparing({
    String message = 'Preparing your dashboard...',
    String detail =
        'We are checking your inbox and getting the latest updates ready.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.preparing,
      title: 'Setting up your dashboard',
      message: message,
      detail: detail,
      progress: 0.15,
    );
  }

  factory SyncUIState.syncing({
    String message = 'Syncing your inbox...',
    String detail = 'New mail is being imported now.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.syncing,
      title: 'Sync in progress',
      message: message,
      detail: detail,
      progress: 0.42,
    );
  }

  factory SyncUIState.processing({
    String message = 'Processing your updates...',
    String detail =
        'AI enrichment and dashboard preparation are still running.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.processing,
      title: 'Finishing up',
      message: message,
      detail: detail,
      progress: 0.78,
    );
  }

  factory SyncUIState.ready({
    String message = 'Your dashboard is ready.',
    String detail = 'The latest mail and AI updates have finished processing.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.ready,
      title: 'Dashboard ready',
      message: message,
      detail: detail,
      progress: 1.0,
    );
  }

  factory SyncUIState.failed({
    String message = 'We could not finish preparing your dashboard.',
    String detail = 'Please try again to restart the sync.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.failed,
      title: 'Sync failed',
      message: message,
      detail: detail,
      progress: 0.0,
    );
  }

  factory SyncUIState.timeout({
    String message = 'Sync is taking longer than expected.',
    String detail =
        'The backend did not finish in time. You can retry the sync.',
  }) {
    return SyncUIState(
      phase: SyncUIPhase.timeout,
      title: 'Sync timed out',
      message: message,
      detail: detail,
      progress: 0.0,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory SyncUIState.fromSyncEvent(
    Map<String, dynamic> event, {
    SyncUIState? previous,
  }) {
    final status = (event['status'] ?? '').toString().trim().toLowerCase();
    final pipelineComplete = event['pipeline_complete'] == true;
    final newMessagesCount = _asInt(event['new_messages_count']);
    final aiPendingCount = _asInt(event['ai_pending_count']);
    final aiFailedCount = _asInt(event['ai_failed_count']);
    final finishedAt = event['finished_at']?.toString().trim();

    if (status == 'failed') {
      return SyncUIState.failed(
        detail: aiFailedCount > 0
            ? '$aiFailedCount item(s) failed during processing.'
            : 'The sync service reported a failure.',
      );
    }

    if (status == 'timeout') {
      return SyncUIState.timeout();
    }

    if (pipelineComplete) {
      return SyncUIState.ready(
        message: newMessagesCount > 0
            ? 'Your dashboard is ready with $newMessagesCount new message(s).'
            : 'Your dashboard is ready.',
        detail: finishedAt != null && finishedAt.isNotEmpty
            ? 'Completed at $finishedAt.'
            : 'The latest mail and AI updates have finished processing.',
      );
    }

    if (status == 'completed' || status == 'no_action') {
      return SyncUIState.processing(
        message: 'Sync finished. Finalizing your dashboard...',
        detail: aiPendingCount > 0
            ? '$aiPendingCount item(s) still need AI processing.'
            : 'The last AI tasks are being drained.',
      );
    }

    if (status == 'stream_closed') {
      return previous ?? SyncUIState.processing();
    }

    if (status == 'processing' ||
        status == 'ai_processing' ||
        status == 'enriching' ||
        aiPendingCount > 0) {
      return SyncUIState.processing(
        detail: aiPendingCount > 0
            ? '$aiPendingCount item(s) are still being processed.'
            : 'AI enrichment is still running.',
      );
    }

    if (status == 'in_progress' ||
        status == 'syncing' ||
        status == 'started' ||
        status == 'running') {
      return SyncUIState.syncing(
        detail: newMessagesCount > 0
            ? '$newMessagesCount message(s) have been found so far.'
            : 'We are pulling in the latest mail now.',
      );
    }

    return previous ?? SyncUIState.preparing();
  }
}
