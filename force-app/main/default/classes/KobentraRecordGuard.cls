public with sharing class KobentraRecordGuard {
  public static Boolean assessmentWriteAllowed = false;
  public static void preferences(
    List<Kobentra_Market_Preference__c> rows,
    Map<Id, Kobentra_Market_Preference__c> oldRows
  ) {
    KobentraAccess.Scope scope = KobentraAccess.business();
    for (Kobentra_Market_Preference__c row : rows) {
      if (oldRows == null)
        row.OwnerId = UserInfo.getUserId();
      if (
        row.Business__c != scope.accountId ||
        (oldRows != null &&
        (row.Business__c != oldRows.get(row.Id).Business__c ||
        row.OwnerId != oldRows.get(row.Id).OwnerId))
      )
        row.addError('Business membership and ownership cannot be changed.');
      row.Country__c = KobentraAccess.required(row.Country__c, 80, 'country');
      row.Request_Key__c =
        String.valueOf(scope.accountId) +
        ':' +
        row.Country__c.toLowerCase() +
        ':' +
        row.Intent__c;
    }
  }
  public static void opportunities(
    List<Kobentra_Opportunity__c> rows,
    Map<Id, Kobentra_Opportunity__c> oldRows
  ) {
    KobentraAccess.Scope scope = KobentraAccess.business();
    Account business = [
      SELECT Name, BillingCountry, Industry
      FROM Account
      WHERE Id = :scope.accountId
      WITH USER_MODE
    ];
    Boolean qualified = KobentraAssessmentService.completed(scope.accountId);
    Boolean markets = ![
        SELECT Id
        FROM Kobentra_Market_Preference__c
        WHERE Business__c = :scope.accountId
        WITH USER_MODE
        LIMIT 1
      ]
      .isEmpty();
    for (Kobentra_Opportunity__c row : rows) {
      Kobentra_Opportunity__c before = oldRows == null
        ? null
        : oldRows.get(row.Id);
      if (before == null)
        row.OwnerId = UserInfo.getUserId();
      if (
        row.Business__c != scope.accountId ||
        (before != null &&
        (row.Business__c != before.Business__c ||
        row.OwnerId != before.OwnerId))
      ) {
        row.addError(
          'Only the owning business may change this opportunity; ownership is fixed.'
        );
        continue;
      }
      if (row.Target_Country__c != null)
        row.Target_Country__c = row.Target_Country__c.trim();
      if (before == null && row.Publication__c == 'Published') {
        row.addError('Save a private draft before publishing.');
        continue;
      }
      Boolean edited =
        before != null &&
        (row.Title__c != before.Title__c ||
        row.Type__c != before.Type__c ||
        row.Category__c != before.Category__c ||
        row.Target_Country__c != before.Target_Country__c ||
        row.Summary__c != before.Summary__c);
      if (before != null && before.Publication__c == 'Published' && edited)
        row.Publication__c = 'Draft';
      if (row.Publication__c == 'Published') {
        if (
          !qualified ||
          !markets ||
          String.isBlank(business.BillingCountry) ||
          String.isBlank(business.Industry) ||
          String.isBlank(row.Title__c) ||
          String.isBlank(row.Type__c) ||
          String.isBlank(row.Category__c) ||
          String.isBlank(row.Target_Country__c) ||
          String.isBlank(row.Summary__c)
        ) {
          row.addError(
            'Complete your profile, market preferences and verified assessment before publication.'
          );
          continue;
        }
        if (before == null || before.Publication__c != 'Published')
          row.Published_At__c = Datetime.now();
        row.Business_Name__c = business.Name;
        row.Business_Country__c = business.BillingCountry;
      } else
        row.Published_At__c = null;
    }
  }
  public static void interests(
    List<Kobentra_Interest__c> rows,
    Map<Id, Kobentra_Interest__c> oldRows
  ) {
    KobentraAccess.Scope scope = KobentraAccess.business();
    Set<Id> ids = new Set<Id>();
    for (Kobentra_Interest__c row : rows)
      ids.add(row.Opportunity__c);
    Map<Id, Kobentra_Opportunity__c> opportunities = new Map<Id, Kobentra_Opportunity__c>(
      [
        SELECT
          Id,
          Business__c,
          Business_Name__c,
          Title__c,
          Target_Country__c,
          Business_Active__c,
          Publication__c
        FROM Kobentra_Opportunity__c
        WHERE Id IN :ids
        WITH USER_MODE
      ]
    );
    Account business = [
      SELECT Name, BillingCountry
      FROM Account
      WHERE Id = :scope.accountId
      WITH USER_MODE
    ];
    Boolean qualified =
      oldRows != null || KobentraAssessmentService.completed(scope.accountId);
    for (Kobentra_Interest__c row : rows) {
      if (oldRows == null) {
        row.OwnerId = UserInfo.getUserId();
        Kobentra_Opportunity__c opportunity = opportunities.get(
          row.Opportunity__c
        );
        if (
          !qualified ||
          opportunity == null ||
          !opportunity.Business_Active__c ||
          opportunity.Publication__c != 'Published' ||
          opportunity.Target_Country__c != business.BillingCountry ||
          opportunity.Business__c == scope.accountId ||
          row.Business__c != scope.accountId
        ) {
          row.addError(
            'A verified assessment and an available opportunity targeting your country are required.'
          );
          continue;
        }
        row.Status__c = 'Requested';
        row.Business_Name__c = business.Name;
        row.Receiver_Name__c = opportunity.Business_Name__c;
        row.Opportunity_Title__c = opportunity.Title__c;
        row.Request_Key__c =
          String.valueOf(scope.accountId) +
          ':' +
          String.valueOf(opportunity.Id);
      } else {
        Kobentra_Interest__c before = oldRows.get(row.Id);
        if (
          row.Business__c != before.Business__c ||
          row.Receiving_Business__c != before.Receiving_Business__c ||
          row.Opportunity__c != before.Opportunity__c ||
          row.Request_Key__c != before.Request_Key__c ||
          row.OwnerId != before.OwnerId
        ) {
          row.addError(
            'Interest participants and ownership cannot be changed.'
          );
          continue;
        }
        if (row.Status__c == before.Status__c)
          continue;
        Boolean receiver =
          row.Receiving_Business__c == scope.accountId &&
          new Set<String>{ 'Accepted', 'Declined' }.contains(row.Status__c);
        Boolean sender =
          row.Business__c == scope.accountId &&
          row.Status__c == 'Withdrawn';
        if (before.Status__c != 'Requested' || (!receiver && !sender))
          row.addError('This decision is not permitted.');
      }
    }
  }
}
