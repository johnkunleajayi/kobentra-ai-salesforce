public with sharing class KobentraAssessmentDispatch {
  @TestVisible
  private static KobentraAssessmentGateway gateway = new KobentraAssessmentGateway();
  public class Request {
    @InvocableVariable(required=true)
    public Id assessmentId;
  }
  @InvocableMethod(
    label='Dispatch Kobentra native assessments'
    description='Internal operator only. Reuses the existing Lead-triggered SurveyVista Flow.'
  )
  public static void dispatch(List<Request> inputs) {
    KobentraAccess.operatorOnly();
    KobentraIntegrationConfig.survey();
    Set<Id> ids = new Set<Id>();
    if (inputs == null || inputs.size() > 50)
      throw new KobentraException('Select up to 50 assessment requests.');
    for (Request input : inputs)
      ids.add(input.assessmentId);
    List<Kobentra_Assessment__c> requests = [
      SELECT Id, Business__c, Lead__c, Status__c, Requested_By_Contact__c
      FROM Kobentra_Assessment__c
      WHERE Id IN :ids
      WITH USER_MODE
      FOR UPDATE
    ];
    if (requests.size() != ids.size())
      throw new KobentraException('An assessment request is unavailable.');
    Set<Id> accountIds = new Set<Id>();
    Set<Id> contactIds = new Set<Id>();
    for (Kobentra_Assessment__c row : requests) {
      accountIds.add(row.Business__c);
      contactIds.add(row.Requested_By_Contact__c);
    }
    Map<Id, Account> businesses = new Map<Id, Account>(
      [
        SELECT Id, Name, BillingCountry, Kobentra_Access__c
        FROM Account
        WHERE Id IN :accountIds
        WITH USER_MODE
      ]
    );
    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, AccountId, LastName, Email
        FROM Contact
        WHERE Id IN :contactIds AND Email != NULL
        WITH USER_MODE
      ]
    );
    List<Lead> leads = new List<Lead>();
    List<Kobentra_Assessment__c> pending = new List<Kobentra_Assessment__c>();
    for (Kobentra_Assessment__c row : requests) {
      if (row.Lead__c != null)
        continue;
      Account business = businesses.get(row.Business__c);
      Contact person = contacts.get(row.Requested_By_Contact__c);
      if (
        business == null ||
        business.Kobentra_Access__c == 'Suspended' ||
        person == null ||
        person.AccountId != row.Business__c
      )
        throw new KobentraException(
          'An active business and its requesting contact email are required.'
        );
      leads.add(
        new Lead(
          Company = business.Name,
          LastName = person.LastName,
          Email = person.Email,
          Country = business.BillingCountry,
          Description = 'Kobentra assessment request ' + row.Id,
          Kobentra_Assessment_Requested__c = true
        )
      );
      pending.add(row);
    }
    if (leads.isEmpty())
      return;
    gateway.createLeads(leads);
    List<Kobentra_Assessment__c> changes = new List<Kobentra_Assessment__c>();
    for (Integer i = 0; i < pending.size(); i++) {
      changes.add(
        new Kobentra_Assessment__c(
          Id = pending[i].Id,
          Lead__c = leads[i].Id,
          Status__c = 'Assigned'
        )
      );
    }
    KobentraRecordGuard.assessmentWriteAllowed = true;
    try {
      update as user changes;
    } finally {
      KobentraRecordGuard.assessmentWriteAllowed = false;
    }
  }
}
