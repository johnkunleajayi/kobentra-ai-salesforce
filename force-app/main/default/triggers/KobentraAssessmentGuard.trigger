trigger KobentraAssessmentGuard on Kobentra_Assessment__c(
  before insert,
  before update
) {
  KobentraAssessmentRecordGuard.enforce(Trigger.new, Trigger.oldMap);
}
