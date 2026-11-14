public with sharing class KobentraAssessmentRecordGuard {
  public static void enforce(
    List<Kobentra_Assessment__c> rows,
    Map<Id, Kobentra_Assessment__c> oldRows
  ) {
    if (oldRows == null) {
      KobentraAccess.Scope scope = KobentraAccess.business();
      String version = KobentraIntegrationConfig.settings().Version__c;
      for (Kobentra_Assessment__c row : rows) {
        if (row.Business__c != scope.accountId)
          row.addError('Business membership is required.');
        row.OwnerId = UserInfo.getUserId();
        row.Status__c = 'Requested';
        row.Lead__c = null;
        row.Survey_Result_Id__c = null;
        row.Completed_At__c = null;
        row.Requested_At__c = Datetime.now();
        row.Requested_By_Contact__c = scope.contactId;
        row.Request_Key__c = String.valueOf(scope.accountId) + ':' + version;
      }
      return;
    }
    KobentraAccess.operatorOnly();
    if (!KobentraRecordGuard.assessmentWriteAllowed)
      throw new KobentraException(
        'Assessment status is managed by verified integration services.'
      );
    for (Kobentra_Assessment__c row : rows) {
      Kobentra_Assessment__c before = oldRows.get(row.Id);
      if (
        row.Business__c != before.Business__c ||
        row.OwnerId != before.OwnerId ||
        row.Request_Key__c != before.Request_Key__c ||
        row.Requested_By_Contact__c != before.Requested_By_Contact__c ||
        row.Requested_At__c != before.Requested_At__c ||
        (before.Lead__c != null &&
        row.Lead__c != before.Lead__c)
      )
        row.addError(
          'Assessment business, requester and established Lead linkage are immutable.'
        );
      if (
        before.Status__c == 'Completed' &&
        (row.Status__c != before.Status__c ||
        row.Survey_Result_Id__c != before.Survey_Result_Id__c ||
        row.Completed_At__c != before.Completed_At__c)
      )
        row.addError('Verified completion is immutable.');
      if (row.Status__c == 'Assigned' && row.Lead__c == null)
        row.addError('An assigned assessment requires its Lead.');
      if (
        row.Status__c == 'Completed' &&
        (row.Lead__c == null ||
        String.isBlank(row.Survey_Result_Id__c) ||
        row.Completed_At__c == null ||
        row.Completed_At__c < row.Requested_At__c ||
        row.Completed_At__c > Datetime.now())
      )
        row.addError(
          'A completed assessment requires verified linkage and a valid completion time.'
        );
    }
  }
}
