@IsTest
private class KobentraProfileTest {
  @TestSetup
  static void setup() {
    KobentraTestData.create();
  }
  @IsTest
  static void savesExistingBusinessAndPreferenceWithoutDuplicates() {
    User supplier = KobentraTestData.member('kobnga');
    System.runAs(supplier) {
      KobentraProfileInput input = new KobentraProfileInput();
      input.name = ' Fictional supplier updated ';
      input.country = 'Nigeria';
      input.industry = 'Manufacturing';
      input.summary = 'Packaged food production';
      input.lastName = 'Supplier';
      input.email = 'supplier@example.invalid';
      input.targetCountry = 'Ghana';
      input.intent = 'Find distributors';
      KobentraController.saveProfile(input);
      KobentraController.saveProfile(input);
      Assert.areEqual(1, [SELECT COUNT() FROM Account WITH USER_MODE]);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Kobentra_Market_Preference__c WITH USER_MODE]
      );
      Map<String, Object> profile = KobentraController.getProfile();
      Assert.areEqual('Fictional supplier updated', profile.get('name'));
      Assert.areEqual('Ghana', profile.get('targetCountry'));
      input.name = ' ';
      try {
        KobentraController.saveProfile(input);
        Assert.fail('Whitespace-only names must fail.');
      } catch (AuraHandledException expected) {
        Assert.isTrue(expected.getMessage().contains('business name'));
      }
    }
  }
  @IsTest
  static void cannotCreatePreferenceForAnotherBusiness() {
    User supplier = KobentraTestData.member('kobnga');
    User other = KobentraTestData.member('kobgha');
    System.runAs(supplier) {
      Database.SaveResult result = Database.insert(
        new Kobentra_Market_Preference__c(
          Business__c = other.Contact.AccountId,
          Country__c = 'Ghana',
          Intent__c = 'Find buyers'
        ),
        false
      );
      Assert.isFalse(result.isSuccess());
    }
  }
}
