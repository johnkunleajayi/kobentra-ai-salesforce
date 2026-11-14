@IsTest
private class KobentraAssessmentTest {
  @TestSetup
  static void setup() {
    KobentraTestData.create();
  }
  private class FakeGateway extends KobentraAssessmentGateway {
    public Integer creates = 0;
    public List<ArdiraSurvey__Survey_Result__c> supplied = new List<ArdiraSurvey__Survey_Result__c>();
    public override void createLeads(List<Lead> rows) {
      creates += rows.size();
      for (Lead row : rows) {
        Assert.isTrue(
          row.Kobentra_Assessment_Requested__c,
          'Production must invoke the existing Flow.'
        );
        row.Kobentra_Assessment_Requested__c = false; // Never send test invitations.
      }
      insert rows;
    }
    public override List<ArdiraSurvey__Survey_Result__c> results(
      Set<Id> leads,
      Id survey
    ) {
      return supplied;
    }
  }
  private static ArdiraSurvey__Survey_Result__c result(
    Id lead,
    Id survey,
    String status,
    Integer sequence
  ) {
    return new ArdiraSurvey__Survey_Result__c(
      Id = KobentraTestData.fakeId(
        ArdiraSurvey__Survey_Result__c.SObjectType,
        sequence
      ),
      ArdiraSurvey__Target_Lead__c = lead,
      ArdiraSurvey__Survey__c = survey,
      ArdiraSurvey__Status__c = status,
      ArdiraSurvey__Response_End_Time__c = Datetime.now()
    );
  }
  @IsTest
  static void operatorOnlyAndDisabledConfiguration() {
    KobentraTestData.configure();
    System.runAs(KobentraTestData.member('kobnga')) {
      try {
        KobentraAssessmentDispatch.dispatch(
          new List<KobentraAssessmentDispatch.Request>()
        );
        Assert.fail('Members cannot dispatch Leads.');
      } catch (KobentraException expected) {
        Assert.isTrue(expected.getMessage().contains('internal'));
      }
    }
    KobentraIntegrationConfig.overrideConfig.Enabled__c = false;
    System.runAs(KobentraTestData.member('kobowner')) {
      try {
        KobentraAssessmentDispatch.dispatch(
          new List<KobentraAssessmentDispatch.Request>()
        );
        Assert.fail('Disabled integration must fail closed.');
      } catch (KobentraException expected) {
        Assert.isTrue(expected.getMessage().contains('configured'));
      }
    }
  }
  @IsTest
  static void exactResultVerificationAndRepeatDispatch() {
    KobentraTestData.configure();
    User supplier = KobentraTestData.member('kobnga');
    Id requestId = KobentraTestData.request(supplier);
    FakeGateway gateway = new FakeGateway();
    KobentraAssessmentDispatch.gateway = gateway;
    KobentraAssessmentReconcile.gateway = gateway;
    System.runAs(KobentraTestData.member('kobowner')) {
      KobentraAssessmentDispatch.Request dispatch = new KobentraAssessmentDispatch.Request();
      dispatch.assessmentId = requestId;
      KobentraAssessmentDispatch.dispatch(
        new List<KobentraAssessmentDispatch.Request>{ dispatch }
      );
      KobentraAssessmentDispatch.dispatch(
        new List<KobentraAssessmentDispatch.Request>{ dispatch }
      );
      Assert.areEqual(1, gateway.creates);
      Id lead = [
        SELECT Lead__c
        FROM Kobentra_Assessment__c
        WHERE Id = :requestId
      ]
      .Lead__c;
      KobentraAssessmentReconcile.Request reconcile = new KobentraAssessmentReconcile.Request();
      reconcile.assessmentId = requestId;
      Id survey = KobentraIntegrationConfig.survey();
      gateway.supplied.add(result(lead, survey, 'In Progress', 1));
      gateway.supplied.add(
        result(
          lead,
          KobentraTestData.fakeId(ArdiraSurvey__Survey__c.SObjectType, 2),
          'Completed',
          2
        )
      );
      KobentraAssessmentReconcile.reconcile(
        new List<KobentraAssessmentReconcile.Request>{ reconcile }
      );
      Assert.areEqual(
        'Assigned',
        [SELECT Status__c FROM Kobentra_Assessment__c WHERE Id = :requestId]
        .Status__c
      );
      gateway.supplied.clear();
      gateway.supplied.add(result(lead, survey, 'Completed', 3));
      KobentraAssessmentReconcile.reconcile(
        new List<KobentraAssessmentReconcile.Request>{ reconcile }
      );
      KobentraAssessmentReconcile.reconcile(
        new List<KobentraAssessmentReconcile.Request>{ reconcile }
      );
      Assert.areEqual(
        'Completed',
        [SELECT Status__c FROM Kobentra_Assessment__c WHERE Id = :requestId]
        .Status__c
      );
    }
    System.runAs(supplier) {
      Assert.isTrue(
        KobentraAssessmentService.completed(supplier.Contact.AccountId)
      );
    }
  }
  @IsTest
  static void ambiguousResultsRequireReview() {
    KobentraTestData.configure();
    Id requestId = KobentraTestData.request(KobentraTestData.member('kobnga'));
    FakeGateway gateway = new FakeGateway();
    KobentraAssessmentDispatch.gateway = gateway;
    KobentraAssessmentReconcile.gateway = gateway;
    System.runAs(KobentraTestData.member('kobowner')) {
      KobentraAssessmentDispatch.Request dispatch = new KobentraAssessmentDispatch.Request();
      dispatch.assessmentId = requestId;
      KobentraAssessmentDispatch.dispatch(
        new List<KobentraAssessmentDispatch.Request>{ dispatch }
      );
      Id lead = [
        SELECT Lead__c
        FROM Kobentra_Assessment__c
        WHERE Id = :requestId
      ]
      .Lead__c;
      Id survey = KobentraIntegrationConfig.survey();
      gateway.supplied.add(result(lead, survey, 'Completed', 1));
      gateway.supplied.add(result(lead, survey, 'Completed', 2));
      KobentraAssessmentReconcile.Request reconcile = new KobentraAssessmentReconcile.Request();
      reconcile.assessmentId = requestId;
      KobentraAssessmentReconcile.reconcile(
        new List<KobentraAssessmentReconcile.Request>{ reconcile }
      );
      Assert.areEqual(
        'Review',
        [SELECT Status__c FROM Kobentra_Assessment__c WHERE Id = :requestId]
        .Status__c
      );
    }
  }
}
