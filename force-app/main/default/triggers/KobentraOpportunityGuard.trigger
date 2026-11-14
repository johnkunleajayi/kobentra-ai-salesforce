trigger KobentraOpportunityGuard on Kobentra_Opportunity__c(
  before insert,
  before update
) {
  KobentraRecordGuard.opportunities(
    Trigger.new,
    Trigger.isInsert ? null : Trigger.oldMap
  );
}
