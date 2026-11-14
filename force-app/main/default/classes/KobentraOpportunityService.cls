public with sharing class KobentraOpportunityService {
  public static void create(KobentraOpportunityInput input) {
    KobentraAccess.Scope scope = KobentraAccess.business();
    if (input == null)
      throw new KobentraException('Enter opportunity details.');
    Kobentra_Opportunity__c record = new Kobentra_Opportunity__c(
      Business__c = scope.accountId,
      Title__c = KobentraAccess.required(input.title, 160, 'opportunity title'),
      Type__c = input.type,
      Category__c = input.category,
      Target_Country__c = input.country,
      Summary__c = input.summary,
      Stage__c = String.isBlank(input.stage) ? 'Exploring' : input.stage
    );
    insert as user record;
  }
  public static void publication(Id opportunityId, String state) {
    if (state != 'Draft' && state != 'Published')
      throw new KobentraException('Choose draft or published.');
    KobentraAccess.Scope scope = KobentraAccess.business();
    List<Kobentra_Opportunity__c> records = [
      SELECT Id, Publication__c
      FROM Kobentra_Opportunity__c
      WHERE Id = :opportunityId AND Business__c = :scope.accountId
      WITH USER_MODE
      FOR UPDATE
    ];
    if (records.isEmpty())
      throw new KobentraException('This opportunity is unavailable.');
    if (records[0].Publication__c == state)
      return;
    records[0].Publication__c = state;
    update as user records;
  }
  public static List<Map<String, Object>> own(Id accountId) {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Kobentra_Opportunity__c row : [
      SELECT
        Id,
        Title__c,
        Type__c,
        Target_Country__c,
        Category__c,
        Summary__c,
        Stage__c,
        Publication__c
      FROM Kobentra_Opportunity__c
      WHERE Business__c = :accountId
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 50
    ]) {
      Map<String, Object> view = project(row);
      view.put('stage', row.Stage__c);
      view.put('publication', row.Publication__c);
      result.add(view);
    }
    return result;
  }
  public static List<Map<String, Object>> discover(KobentraAccess.Scope scope) {
    if (!KobentraAssessmentService.completed(scope.accountId))
      return new List<Map<String, Object>>();
    Account business = [
      SELECT BillingCountry
      FROM Account
      WHERE Id = :scope.accountId
      WITH USER_MODE
    ];
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Kobentra_Opportunity__c row : [
      SELECT
        Id,
        Title__c,
        Type__c,
        Target_Country__c,
        Category__c,
        Summary__c,
        Business_Name__c,
        Business_Country__c
      FROM Kobentra_Opportunity__c
      WHERE
        Publication__c = 'Published'
        AND Published_At__c != NULL
        AND Business_Active__c = TRUE
        AND Target_Country__c = :business.BillingCountry
        AND Business__c != :scope.accountId
      WITH USER_MODE
      ORDER BY Published_At__c DESC
      LIMIT 30
    ]) {
      Map<String, Object> view = project(row);
      view.put('businessName', row.Business_Name__c);
      view.put('businessCountry', row.Business_Country__c);
      view.put(
        'reason',
        'Published for your business country. Information is business-provided, not an independent verification.'
      );
      result.add(view);
    }
    return result;
  }
  private static Map<String, Object> project(Kobentra_Opportunity__c row) {
    return new Map<String, Object>{
      'id' => row.Id,
      'title' => row.Title__c,
      'type' => row.Type__c,
      'country' => row.Target_Country__c,
      'category' => row.Category__c,
      'summary' => row.Summary__c
    };
  }
}
