public with sharing class KobentraAssessmentReconcile {
  @TestVisible
  private static KobentraAssessmentGateway gateway = new KobentraAssessmentGateway();
  public class Request {
    @InvocableVariable(required=true)
    public Id assessmentId;
  }
  @InvocableMethod(
    label='Verify Kobentra SurveyVista completion'
    description='Verifies exact Lead, configured survey, Completed status and completion time. No answers are exposed.'
  )
  public static void reconcile(List<Request> inputs) {
    KobentraAccess.operatorOnly();
    Id survey = KobentraIntegrationConfig.survey();
    if (inputs == null || inputs.size() > 50)
      throw new KobentraException('Select up to 50 requests.');
    Set<Id> ids = new Set<Id>();
    for (Request input : inputs)
      ids.add(input.assessmentId);
    List<Kobentra_Assessment__c> requests = [
      SELECT
        Id,
        Lead__c,
        Requested_At__c,
        Status__c,
        Survey_Result_Id__c,
        Completed_At__c
      FROM Kobentra_Assessment__c
      WHERE Id IN :ids
      WITH USER_MODE
      FOR UPDATE
    ];
    if (requests.size() != ids.size())
      throw new KobentraException('An assessment request is unavailable.');
    Set<Id> leads = new Set<Id>();
    for (Kobentra_Assessment__c row : requests)
      if (row.Lead__c != null)
        leads.add(row.Lead__c);
    Map<Id, List<ArdiraSurvey__Survey_Result__c>> byLead = new Map<Id, List<ArdiraSurvey__Survey_Result__c>>();
    if (!leads.isEmpty())
      for (
        ArdiraSurvey__Survey_Result__c result : gateway.results(leads, survey)
      ) {
        if (
          !leads.contains(result.ArdiraSurvey__Target_Lead__c) ||
          result.ArdiraSurvey__Survey__c != survey ||
          result.ArdiraSurvey__Status__c != 'Completed' ||
          result.ArdiraSurvey__Response_End_Time__c == null
        )
          continue;
        if (!byLead.containsKey(result.ArdiraSurvey__Target_Lead__c))
          byLead.put(
            result.ArdiraSurvey__Target_Lead__c,
            new List<ArdiraSurvey__Survey_Result__c>()
          );
        byLead.get(result.ArdiraSurvey__Target_Lead__c).add(result);
      }
    List<Kobentra_Assessment__c> changed = new List<Kobentra_Assessment__c>();
    for (Kobentra_Assessment__c row : requests) {
      if (row.Status__c == 'Completed' || !byLead.containsKey(row.Lead__c))
        continue;
      List<ArdiraSurvey__Survey_Result__c> results = byLead.get(row.Lead__c);
      if (
        results.size() != 1 ||
        results[0].ArdiraSurvey__Response_End_Time__c < row.Requested_At__c ||
        results[0].ArdiraSurvey__Response_End_Time__c > Datetime.now()
      )
        row.Status__c = 'Review';
      else {
        row.Status__c = 'Completed';
        row.Survey_Result_Id__c = String.valueOf(results[0].Id);
        row.Completed_At__c = results[0].ArdiraSurvey__Response_End_Time__c;
      }
      changed.add(
        new Kobentra_Assessment__c(
          Id = row.Id,
          Status__c = row.Status__c,
          Survey_Result_Id__c = row.Survey_Result_Id__c,
          Completed_At__c = row.Completed_At__c
        )
      );
    }
    if (changed.isEmpty())
      return;
    KobentraRecordGuard.assessmentWriteAllowed = true;
    try {
      update as user changed;
    } finally {
      KobentraRecordGuard.assessmentWriteAllowed = false;
    }
  }
}
