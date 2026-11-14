public with sharing class KobentraProfileService {
  public static Map<String, Object> read() {
    KobentraAccess.Scope scope = KobentraAccess.business();
    Account a = [
      SELECT Name, BillingCountry, Industry, Description
      FROM Account
      WHERE Id = :scope.accountId
      WITH USER_MODE
    ];
    Contact c = [
      SELECT FirstName, LastName, Email
      FROM Contact
      WHERE Id = :scope.contactId
      WITH USER_MODE
    ];
    List<Kobentra_Market_Preference__c> preferences = [
      SELECT Country__c, Intent__c
      FROM Kobentra_Market_Preference__c
      WHERE Business__c = :scope.accountId
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    List<Map<String, String>> industries = new List<Map<String, String>>();
    for (
      Schema.PicklistEntry item : Account.Industry.getDescribe()
        .getPicklistValues()
    ) {
      if (item.isActive())
        industries.add(
          new Map<String, String>{
            'label' => item.getLabel(),
            'value' => item.getValue()
          }
        );
    }
    return new Map<String, Object>{
      'name' => a.Name,
      'country' => a.BillingCountry,
      'industry' => a.Industry,
      'summary' => a.Description,
      'firstName' => c.FirstName,
      'lastName' => c.LastName,
      'email' => c.Email,
      'industries' => industries,
      'targetCountry' => preferences.isEmpty()
        ? null
        : preferences[0].Country__c,
      'intent' => preferences.isEmpty() ? null : preferences[0].Intent__c
    };
  }
  public static void save(KobentraProfileInput input) {
    if (input == null)
      throw new KobentraException('Complete your business profile.');
    KobentraAccess.Scope scope = KobentraAccess.business();
    String email = KobentraAccess.required(input.email, 80, 'contact email');
    if (!Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', email))
      throw new KobentraException('Enter a valid business contact email.');
    String country = KobentraAccess.required(
      input.targetCountry,
      80,
      'target market'
    );
    String intent = KobentraAccess.required(
      input.intent,
      40,
      'partnership interest'
    );
    Account business = new Account(
      Id = scope.accountId,
      Name = KobentraAccess.required(input.name, 255, 'business name'),
      BillingCountry = KobentraAccess.required(
        input.country,
        80,
        'business country'
      ),
      Industry = KobentraAccess.required(input.industry, 80, 'industry'),
      Description = KobentraAccess.required(
        input.summary,
        1200,
        'business summary'
      )
    );
    Contact contact = new Contact(
      Id = scope.contactId,
      FirstName = input.firstName,
      LastName = KobentraAccess.required(input.lastName, 80, 'last name'),
      Email = email
    );
    update as user business;
    update as user contact;
    List<Kobentra_Market_Preference__c> existing = [
      SELECT Id
      FROM Kobentra_Market_Preference__c
      WHERE
        Business__c = :scope.accountId
        AND Country__c = :country
        AND Intent__c = :intent
      WITH USER_MODE
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      Kobentra_Market_Preference__c preference = new Kobentra_Market_Preference__c(
        Business__c = scope.accountId,
        Country__c = country,
        Intent__c = intent
      );
      insert as user preference;
    }
  }
}
