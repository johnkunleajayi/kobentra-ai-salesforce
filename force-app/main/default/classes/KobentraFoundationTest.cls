@IsTest
private class KobentraFoundationTest {
  @TestSetup
  static void setup() {
    KobentraTestData.create();
  }
  @IsTest
  static void deniesUnprovisionedInternalUser() {
    try {
      KobentraController.getWorkspace();
      Assert.fail(
        'Internal users without business membership must not use tenant APIs.'
      );
    } catch (AuraHandledException error) {
      Assert.isTrue(error.getMessage().contains('authorized business'));
    }
  }
  @IsTest
  static void requestsArePrivateAndIdempotent() {
    KobentraTestData.configure();
    User supplier = KobentraTestData.member('kobnga');
    User distributor = KobentraTestData.member('kobgha');
    Id requestId = KobentraTestData.request(supplier);
    System.runAs(supplier) {
      KobentraAssessmentService.request();
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Kobentra_Assessment__c WITH USER_MODE]
      );
      Assert.areEqual(
        false,
        KobentraAssessmentService.completed(supplier.Contact.AccountId)
      );
      Database.SaveResult result = Database.update(
        new Kobentra_Assessment__c(Id = requestId, Status__c = 'Completed'),
        false
      );
      Assert.isFalse(
        result.isSuccess(),
        'Direct status forgery must fail even without the controller.'
      );
    }
    System.runAs(distributor) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Kobentra_Assessment__c WITH USER_MODE]
      );
    }
  }
  @IsTest
  static void publicationRequiresVerifiedCompletionAndOwner() {
    KobentraTestData.configure();
    User supplier = KobentraTestData.member('kobnga');
    User distributor = KobentraTestData.member('kobgha');
    Id opportunityId = KobentraTestData.draft(supplier);
    System.runAs(supplier) {
      try {
        KobentraOpportunityService.publication(opportunityId, 'Published');
        Assert.fail('Unqualified publication must fail.');
      } catch (DmlException expected) {
        Assert.isTrue(expected.getMessage().contains('verified assessment'));
      }
      Assert.areEqual(
        'Draft',
        [
          SELECT Publication__c
          FROM Kobentra_Opportunity__c
          WHERE Id = :opportunityId
          WITH USER_MODE
        ]
        .Publication__c
      );
    }
    System.runAs(distributor) {
      try {
        KobentraOpportunityService.publication(opportunityId, 'Published');
        Assert.fail('Foreign publication must fail.');
      } catch (KobentraException expected) {
        Assert.isTrue(expected.getMessage().contains('unavailable'));
      }
    }
    KobentraTestData.qualify(supplier);
    System.runAs(supplier) {
      KobentraOpportunityService.publication(opportunityId, 'Published');
      Datetime stamp = [
        SELECT Published_At__c
        FROM Kobentra_Opportunity__c
        WHERE Id = :opportunityId
        WITH USER_MODE
      ]
      .Published_At__c;
      KobentraOpportunityService.publication(opportunityId, 'Published');
      Assert.areEqual(
        stamp,
        [
          SELECT Published_At__c
          FROM Kobentra_Opportunity__c
          WHERE Id = :opportunityId
          WITH USER_MODE
        ]
        .Published_At__c
      );
      update as user new Kobentra_Opportunity__c(
        Id = opportunityId,
        Summary__c = 'Edited private description'
      );
      Assert.areEqual(
        'Draft',
        [
          SELECT Publication__c
          FROM Kobentra_Opportunity__c
          WHERE Id = :opportunityId
          WITH USER_MODE
        ]
        .Publication__c
      );
    }
  }
  @IsTest
  static void publishedDiscoveryAndTwoPartyInterest() {
    KobentraTestData.configure();
    User supplier = KobentraTestData.member('kobnga');
    User distributor = KobentraTestData.member('kobgha');
    KobentraTestData.qualify(supplier);
    KobentraTestData.qualify(distributor);
    Id opportunityId = KobentraTestData.draft(supplier);
    System.runAs(supplier) {
      KobentraOpportunityService.publication(opportunityId, 'Published');
      // Simulates only the explicitly published Read sharing rule, not Account sharing.
      insert new Kobentra_Opportunity__Share(
        ParentId = opportunityId,
        UserOrGroupId = distributor.Id,
        AccessLevel = 'Read',
        RowCause = Schema.Kobentra_Opportunity__Share.RowCause.Manual
      );
    }
    Id interestId;
    System.runAs(distributor) {
      List<Map<String, Object>> discovery = KobentraOpportunityService.discover(
        KobentraAccess.business()
      );
      Assert.areEqual(1, discovery.size());
      Assert.isFalse(discovery[0].containsKey('email'));
      Assert.isFalse(discovery[0].containsKey('Business__c'));
      Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM Contact
          WHERE Id = :supplier.ContactId
          WITH USER_MODE
        ]
      );
      KobentraInterestService.express(opportunityId);
      KobentraInterestService.express(opportunityId);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Kobentra_Interest__c WITH USER_MODE]
      );
      interestId = [SELECT Id FROM Kobentra_Interest__c WITH USER_MODE LIMIT 1]
      .Id;
      try {
        KobentraInterestService.decide(interestId, 'Accepted');
        Assert.fail('Sender cannot accept own interest.');
      } catch (DmlException expected) {
        Assert.isTrue(expected.getMessage().contains('not permitted'));
      }
    }
    System.runAs(supplier) {
      KobentraInterestService.decide(interestId, 'Accepted');
      Assert.areEqual(
        'Accepted',
        [
          SELECT Status__c
          FROM Kobentra_Interest__c
          WHERE Id = :interestId
          WITH USER_MODE
        ]
        .Status__c
      );
      KobentraOpportunityService.publication(opportunityId, 'Draft');
    }
    System.runAs(distributor) {
      Assert.areEqual(
        0,
        KobentraOpportunityService.discover(KobentraAccess.business()).size()
      );
    }
  }
  @IsTest
  static void suspensionBlocksBusinessOperations() {
    KobentraTestData.configure();
    User supplier = KobentraTestData.member('kobnga');
    update new Account(
      Id = supplier.Contact.AccountId,
      Kobentra_Access__c = 'Suspended'
    );
    System.runAs(supplier) {
      try {
        KobentraAssessmentService.request();
        Assert.fail('Suspension must be enforced.');
      } catch (KobentraException expected) {
        Assert.isTrue(expected.getMessage().contains('suspended'));
      }
    }
  }
}
