class SyncState {
  const SyncState({
    required this.documentId,
    required this.remotePath,
    required this.remoteModified,
    required this.syncedUpdatedAt,
    required this.syncedAt,
  });

  final String documentId;
  final String remotePath;
  final DateTime remoteModified;
  final DateTime syncedUpdatedAt;
  final DateTime syncedAt;
}
