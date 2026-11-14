@IsTest
public class KobentraTestData {
  public static void create() {
    UserRole role = new UserRole(Name = 'Kobentra test owner');
    insert role;
    Profile internalProfile = [
      SELECT Id
      FROM Profile
      WHERE PermissionsModifyAllData = TRUE AND UserLicense.Name = 'Salesforce'
      LIMIT 1
    ];
    User owner = user('kobowner', internalProfile.Id, null);
    owner.UserRoleId = role.Id;
    insert owner;
    List<PermissionSet> permissions = [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('Kobentra_Assessment_Operator', 'Kobentra_Business_User')
    ];
    Map<String, Id> sets = new Map<String, Id>();
    for (PermissionSet permission : permissions)
      sets.put(permission.Name, permission.Id);
    insert new PermissionSetAssignment(
      AssigneeId = owner.Id,
      PermissionSetId = sets.get('Kobentra_Assessment_Operator')
    );
    System.runAs(owner) {
      List<Account> businesses = new List<Account>{
        new Account(
          Name = 'Fictional Lagos Producer',
          BillingCountry = 'Nigeria',
          Industry = 'Manufacturing',
          OwnerId = owner.Id
        ),
        new Account(
          Name = 'Fictional Accra Distributor',
          BillingCountry = 'Ghana',
          Industry = 'Manufacturing',
          OwnerId = owner.Id
        )
      };
      insert businesses;
      List<Contact> contacts = new List<Contact>{
        new Contact(
          AccountId = businesses[0].Id,
          LastName = 'Supplier',
          Email = 'supplier@example.invalid'
        ),
        new Contact(
          AccountId = businesses[1].Id,
          LastName = 'Distributor',
          Email = 'distributor@example.invalid'
        )
      };
      insert contacts;
      Profile externalProfile = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Customer Community Plus User'
        LIMIT 1
      ];
      List<User> members = new List<User>{
        user('kobnga', externalProfile.Id, contacts[0].Id),
        user('kobgha', externalProfile.Id, contacts[1].Id)
      };
      insert members;
      List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
      for (User member : members)
        assignments.add(
          new PermissionSetAssignment(
            AssigneeId = member.Id,
            PermissionSetId = sets.get('Kobentra_Business_User')
          )
        );
      insert assignments;
      List<AccountShare> accountShares = new List<AccountShare>();
      for (Integer i = 0; i < 2; i++) {
        accountShares.add(
          new AccountShare(
            AccountId = businesses[i].Id,
            UserOrGroupId = members[i].Id,
            AccountAccessLevel = 'Edit',
            OpportunityAccessLevel = 'None',
            CaseAccessLevel = 'None'
          )
        );
      }
      insert accountShares;
    }
  }
  private static User user(String alias, Id profileId, Id contactId) {
    String unique =
      alias +
      String.valueOf(Datetime.now().getTime()) +
      String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    return new User(
      Alias = alias,
      LastName = alias,
      Username = unique + '@example.invalid',
      Email = alias + '@example.invalid',
      CommunityNickname = unique,
      ProfileId = profileId,
      ContactId = contactId,
      TimeZoneSidKey = 'Africa/Lagos',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
  }
  public static User member(String alias) {
    return [
      SELECT Id, ContactId, Contact.AccountId
      FROM User
      WHERE Alias = :alias
      LIMIT 1
    ];
  }
  public static void configure() {
    KobentraIntegrationConfig.overrideConfig = new Kobentra_Integration__mdt(
      Version__c = 'test-v1',
      Enabled__c = true,
      Survey_Id__c = String.valueOf(
        fakeId(ArdiraSurvey__Survey__c.SObjectType, 1)
      )
    );
  }
  public static Id fakeId(Schema.SObjectType type, Integer sequence) {
    return Id.valueOf(
      type.getDescribe().getKeyPrefix() +
      String.valueOf(sequence).leftPad(12, '0')
    );
  }
  public static Id request(User member) {
    System.runAs(member) {
      KobentraAssessmentService.request();
    }
    return [
      SELECT Id
      FROM Kobentra_Assessment__c
      WHERE Business__c = :member.Contact.AccountId
      LIMIT 1
    ]
    .Id;
  }
  public static void qualify(User member) {
    Id requestId = request(member);
    System.runAs(KobentraTestData.member('kobowner')) {
      // Isolated test-only linkage, without the invitation-triggering checkbox.
      Lead lead = new Lead(Company = 'Fictional fixture', LastName = 'Fixture');
      insert lead;
      KobentraRecordGuard.assessmentWriteAllowed = true;
      try {
        update new Kobentra_Assessment__c(
          Id = requestId,
          Lead__c = lead.Id,
          Status__c = 'Completed',
          Survey_Result_Id__c = String.valueOf(
            fakeId(ArdiraSurvey__Survey_Result__c.SObjectType, 1)
          ),
          Completed_At__c = Datetime.now()
        );
      } finally {
        KobentraRecordGuard.assessmentWriteAllowed = false;
      }
    }
  }
  public static Id draft(User member) {
    System.runAs(member) {
      insert new Kobentra_Market_Preference__c(
        Business__c = member.Contact.AccountId,
        Country__c = 'Ghana',
        Intent__c = 'Find distributors'
      );
      KobentraOpportunityInput input = new KobentraOpportunityInput();
      input.title = 'Fictional packaged-food distribution';
      input.type = 'Distribution';
      input.category = 'Packaged food';
      input.country = 'Ghana';
      input.summary = 'Fictional local test opportunity.';
      input.stage = 'Exploring';
      KobentraOpportunityService.create(input);
    }
    return [
      SELECT Id
      FROM Kobentra_Opportunity__c
      WHERE Business__c = :member.Contact.AccountId
      LIMIT 1
    ]
    .Id;
  }
}


