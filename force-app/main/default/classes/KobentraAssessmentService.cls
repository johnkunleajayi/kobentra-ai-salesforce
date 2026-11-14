public with sharing class KobentraAssessmentService {
  public static void request() {
    KobentraAccess.Scope scope = KobentraAccess.business();
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
      KobentraIntegrationConfig.settings().Version__c;
    List<Kobentra_Assessment__c> requests = [
      SELECT Id
      FROM Kobentra_Assessment__c
      WHERE Request_Key__c = :key
      WITH USER_MODE
      LIMIT 1
    ];
    if (!requests.isEmpty())
      return;
    Kobentra_Assessment__c record = new Kobentra_Assessment__c(
      Business__c = scope.accountId
    );
    insert as user record;
  }
  public static Boolean completed(Id accountId) {
    String key =
      String.valueOf(accountId) +
      ':' +
      KobentraIntegrationConfig.settings().Version__c;
    return ![
        SELECT Id
        FROM Kobentra_Assessment__c
        WHERE
          Business__c = :accountId
          AND Request_Key__c = :key
          AND Status__c = 'Completed'
        WITH USER_MODE
        LIMIT 1
      ]
      .isEmpty();
  }
  public static Map<String, Object> status(Id accountId) {
    String key =
      String.valueOf(accountId) +
      ':' +
      KobentraIntegrationConfig.settings().Version__c;
    List<Kobentra_Assessment__c> rows = [
      SELECT Status__c, Requested_At__c, Completed_At__c
      FROM Kobentra_Assessment__c
      WHERE Business__c = :accountId AND Request_Key__c = :key
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return rows.isEmpty()
      ? new Map<String, Object>{ 'status' => 'Not requested' }
      : new Map<String, Object>{
          'status' => rows[0].Status__c,
          'requestedAt' => rows[0].Requested_At__c,
          'completedAt' => rows[0].Completed_At__c
        };
  }
}
