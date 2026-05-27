enum SyncStatus {
  localDraft('LOCAL_DRAFT'),
  pendingSync('PENDING_SYNC'),
  synced('SYNCED'),
  syncFailed('SYNC_FAILED');

  const SyncStatus(this.value);

  final String value;

  static SyncStatus fromValue(String? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.localDraft,
    );
  }
}

enum OutboxOperation {
  createPatient('CREATE_PATIENT'),
  updatePatient('UPDATE_PATIENT'),
  createConsultation('CREATE_CONSULTATION'),
  submitDiagnosis('SUBMIT_DIAGNOSIS'),
  requestExpertise('REQUEST_EXPERTISE'),
  sendChatMessage('SEND_CHAT_MESSAGE');

  const OutboxOperation(this.value);

  final String value;
}

enum OfflineEntityType {
  patient('PATIENT'),
  consultation('CONSULTATION'),
  otoscopicImage('OTOSCOPIC_IMAGE'),
  expertiseRequest('EXPERTISE_REQUEST'),
  chatMessage('CHAT_MESSAGE');

  const OfflineEntityType(this.value);

  final String value;
}
