trigger KobentraMarketGuard on Kobentra_Market_Preference__c(
  before insert,
  before update
) {
  KobentraRecordGuard.preferences(
    Trigger.new,
    Trigger.isInsert ? null : Trigger.oldMap
  );
}
