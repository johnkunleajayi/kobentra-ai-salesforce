trigger KobentraInterestGuard on Kobentra_Interest__c(
  before insert,
  before update,
  after insert
) {
  if (Trigger.isBefore)
    KobentraRecordGuard.interests(
      Trigger.new,
      Trigger.isInsert ? null : Trigger.oldMap
    );
  else
    KobentraInterestSharing.shareWithPublisher(Trigger.new);
}
