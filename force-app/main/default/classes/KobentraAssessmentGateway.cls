public virtual with sharing class KobentraAssessmentGateway {
  public virtual void createLeads(List<Lead> leads) {
    insert as user leads;
  }
  public virtual List<ArdiraSurvey__Survey_Result__c> results(
    Set<Id> leadIds,
    Id survey
  ) {
    List<ArdiraSurvey__Survey_Result__c> rows = [
      SELECT
        Id,
        ArdiraSurvey__Target_Lead__c,
        ArdiraSurvey__Survey__c,
        ArdiraSurvey__Status__c,
        ArdiraSurvey__Response_End_Time__c
      FROM ArdiraSurvey__Survey_Result__c
      WHERE
        ArdiraSurvey__Target_Lead__c IN :leadIds
        AND ArdiraSurvey__Survey__c = :survey
      WITH USER_MODE
      LIMIT 1001
    ];
    if (rows.size() > 1000)
      throw new KobentraException(
        'Too many survey results; an operator must narrow the reconciliation batch.'
      );
    return rows;
  }
}
