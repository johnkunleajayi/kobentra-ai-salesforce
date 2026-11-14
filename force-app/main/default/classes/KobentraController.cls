public with sharing class KobentraController {
  @AuraEnabled
  public static Map<String, Object> getProfile() {
    try {
      return KobentraProfileService.read();
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void saveProfile(KobentraProfileInput input) {
    try {
      KobentraProfileService.save(input);
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static Map<String, Object> getWorkspace() {
    try {
      KobentraAccess.Scope scope = KobentraAccess.business();
      List<String> markets = new List<String>();
      for (Kobentra_Market_Preference__c row : [
        SELECT Country__c, Intent__c
        FROM Kobentra_Market_Preference__c
        WHERE Business__c = :scope.accountId
        WITH USER_MODE
        ORDER BY CreatedDate
        LIMIT 50
      ])
        markets.add(row.Country__c + ' · ' + row.Intent__c);
      return new Map<String, Object>{
        'profile' => KobentraProfileService.read(),
        'assessment' => KobentraAssessmentService.status(scope.accountId),
        'qualified' => KobentraAssessmentService.completed(scope.accountId),
        'markets' => markets,
        'opportunities' => KobentraOpportunityService.own(scope.accountId),
        'discovery' => KobentraOpportunityService.discover(scope),
        'interests' => KobentraInterestService.read(scope.accountId)
      };
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void requestAssessment() {
    try {
      KobentraAssessmentService.request();
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void createOpportunity(KobentraOpportunityInput input) {
    try {
      KobentraOpportunityService.create(input);
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void setPublication(Id opportunityId, String state) {
    try {
      KobentraOpportunityService.publication(opportunityId, state);
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void expressInterest(Id opportunityId) {
    try {
      KobentraInterestService.express(opportunityId);
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
  @AuraEnabled
  public static void decideInterest(Id interestId, String decision) {
    try {
      KobentraInterestService.decide(interestId, decision);
    } catch (Exception error) {
      throw KobentraAccess.safe(error);
    }
  }
}
