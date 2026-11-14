public with sharing class KobentraAccess {
  public class Scope {
    public Id accountId;
    public Id contactId;
    public Scope(Id business, Id contact) {
      accountId = business;
      contactId = contact;
    }
  }
  public static Scope business() {
    if (
      UserInfo.getUserType() == 'Guest' ||
      !FeatureManagement.checkPermission('Kobentra_Business_User')
    ) {
      throw new KobentraException(
        'Sign in with an authorized business account.'
      );
    }
    User actor = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH USER_MODE
    ];
    if (actor.ContactId == null)
      throw new KobentraException(
        'A business Contact must be provisioned for this account.'
      );
    Contact member = [
      SELECT Id, AccountId
      FROM Contact
      WHERE Id = :actor.ContactId
      WITH USER_MODE
    ];
    if (member.AccountId == null)
      throw new KobentraException('Business membership is unavailable.');
    Account business = [
      SELECT Id, Kobentra_Access__c
      FROM Account
      WHERE Id = :member.AccountId
      WITH USER_MODE
    ];
    if (business.Kobentra_Access__c == 'Suspended')
      throw new KobentraException('Business access is suspended.');
    return new Scope(business.Id, member.Id);
  }
  public static void operatorOnly() {
    if (
      UserInfo.getUserType() != 'Standard' ||
      !FeatureManagement.checkPermission('Kobentra_Assessment_Operator')
    ) {
      throw new KobentraException(
        'An authorized internal assessment operator is required.'
      );
    }
  }
  public static String required(String value, Integer maximum, String label) {
    if (String.isBlank(value) || value.trim().length() > maximum)
      throw new KobentraException('Check ' + label + '.');
    return value.trim();
  }
  public static AuraHandledException safe(Exception error) {
    String message = error instanceof KobentraException
      ? error.getMessage()
      : 'This action could not be completed. Check access and try again.';
    AuraHandledException result = new AuraHandledException(message);
    result.setMessage(message);
    return result;
  }
}
