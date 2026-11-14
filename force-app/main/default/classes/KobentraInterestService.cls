public with sharing class KobentraInterestService {
  public static void express(Id opportunityId) {
    KobentraAccess.Scope scope = KobentraAccess.business();
    if (!KobentraAssessmentService.completed(scope.accountId))
      throw new KobentraException(
        'Complete your verified assessment before expressing interest.'
      );
    List<Kobentra_Opportunity__c> opportunities = [
      SELECT Id, Business__c
      FROM Kobentra_Opportunity__c
      WHERE
        Id = :opportunityId
        AND Publication__c = 'Published'
        AND Business_Active__c = TRUE
        AND Business__c != :scope.accountId
      WITH USER_MODE
      LIMIT 1
    ];
    if (opportunities.isEmpty())
      throw new KobentraException('This published opportunity is unavailable.');
    Account locked = [
      SELECT Id
      FROM Account
      WHERE Id = :scope.accountId
      WITH USER_MODE
      FOR UPDATE
    ];
    String key =
      String.valueOf(locked.Id) +
      ':' +
      String.valueOf(opportunityId);
    if (
      ![
          SELECT Id
          FROM Kobentra_Interest__c
          WHERE Request_Key__c = :key
          WITH USER_MODE
          LIMIT 1
        ]
        .isEmpty()
    )
      return;
    Kobentra_Interest__c interest = new Kobentra_Interest__c(
      Business__c = scope.accountId,
      Opportunity__c = opportunityId
    );
    insert as user interest;
  }
  public static void decide(Id interestId, String decision) {
    if (
      !new Set<String>{ 'Accepted', 'Declined', 'Withdrawn' }.contains(decision)
    )
      throw new KobentraException('Choose an available decision.');
    KobentraAccess.Scope scope = KobentraAccess.business();
    List<Kobentra_Interest__c> rows = [
      SELECT Id, Business__c, Receiving_Business__c, Status__c
      FROM Kobentra_Interest__c
      WHERE
        Id = :interestId
        AND (Business__c = :scope.accountId
        OR Receiving_Business__c = :scope.accountId)
      WITH USER_MODE
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new KobentraException('This interest is unavailable.');
    if (rows[0].Status__c == decision)
      return;
    Kobentra_Interest__c change = new Kobentra_Interest__c(
      Id = rows[0].Id,
      Status__c = decision
    );
    update as user change;
  }
  public static List<Map<String, Object>> read(Id accountId) {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Kobentra_Interest__c row : [
      SELECT
        Id,
        Status__c,
        Business__c,
        Receiving_Business__c,
        Business_Name__c,
        Receiver_Name__c,
        Opportunity_Title__c
      FROM Kobentra_Interest__c
      WHERE Business__c = :accountId OR Receiving_Business__c = :accountId
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 50
    ]) {
      result.add(
        new Map<String, Object>{
          'id' => row.Id,
          'title' => row.Opportunity_Title__c,
          'status' => row.Status__c,
          'businessName' => row.Business_Name__c,
          'receiverName' => row.Receiver_Name__c,
          'incoming' => row.Receiving_Business__c == accountId
        }
      );
    }
    return result;
  }
}
