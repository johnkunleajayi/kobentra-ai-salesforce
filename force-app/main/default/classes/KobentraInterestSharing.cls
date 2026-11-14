public with sharing class KobentraInterestSharing {
  public static void shareWithPublisher(List<Kobentra_Interest__c> rows) {
    Set<Id> ids = new Set<Id>();
    for (Kobentra_Interest__c row : rows)
      ids.add(row.Opportunity__c);
    Map<Id, Kobentra_Opportunity__c> opportunities = new Map<Id, Kobentra_Opportunity__c>(
      [
        SELECT Id, OwnerId
        FROM Kobentra_Opportunity__c
        WHERE Id IN :ids
        WITH USER_MODE
      ]
    );
    List<Kobentra_Interest__Share> grants = new List<Kobentra_Interest__Share>();
    for (Kobentra_Interest__c row : rows) {
      Id recipient = opportunities.get(row.Opportunity__c).OwnerId;
      if (recipient != UserInfo.getUserId())
        grants.add(
          new Kobentra_Interest__Share(
            ParentId = row.Id,
            UserOrGroupId = recipient,
            AccessLevel = 'Edit',
            RowCause = Schema.Kobentra_Interest__Share.RowCause.Manual
          )
        );
    }
    // Sole narrow elevation: grant the verified opportunity owner access to an explicitly sent interest.
    // No business/assessment/Contact query or write uses system mode here.
    if (!grants.isEmpty())
      Database.insert(grants, AccessLevel.SYSTEM_MODE);
  }
}
