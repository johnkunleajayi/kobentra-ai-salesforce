public with sharing class KobentraAssessmentScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    KobentraAccess.operatorOnly();
    List<KobentraAssessmentDispatch.Request> dispatches = new List<KobentraAssessmentDispatch.Request>();
    for (Kobentra_Assessment__c row : [
      SELECT Id
      FROM Kobentra_Assessment__c
      WHERE Status__c = 'Requested'
      WITH USER_MODE
      ORDER BY CreatedDate
      LIMIT 10
    ]) {
      KobentraAssessmentDispatch.Request input = new KobentraAssessmentDispatch.Request();
      input.assessmentId = row.Id;
      dispatches.add(input);
    }
    if (!dispatches.isEmpty())
      KobentraAssessmentDispatch.dispatch(dispatches);
    List<KobentraAssessmentReconcile.Request> reconciliations = new List<KobentraAssessmentReconcile.Request>();
    for (Kobentra_Assessment__c row : [
      SELECT Id
      FROM Kobentra_Assessment__c
      WHERE Status__c = 'Assigned'
      WITH USER_MODE
      ORDER BY CreatedDate
      LIMIT 10
    ]) {
      KobentraAssessmentReconcile.Request input = new KobentraAssessmentReconcile.Request();
      input.assessmentId = row.Id;
      reconciliations.add(input);
    }
    if (!reconciliations.isEmpty())
      KobentraAssessmentReconcile.reconcile(reconciliations);
  }
}
