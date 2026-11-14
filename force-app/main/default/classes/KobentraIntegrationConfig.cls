public with sharing class KobentraIntegrationConfig {
  @TestVisible
  private static Kobentra_Integration__mdt overrideConfig;
  public static Kobentra_Integration__mdt settings() {
    Kobentra_Integration__mdt config = Test.isRunningTest() &&
      overrideConfig != null
      ? overrideConfig
      : Kobentra_Integration__mdt.getInstance('Default');
    if (config == null || String.isBlank(config.Version__c))
      throw new KobentraException('Assessment configuration is unavailable.');
    return config;
  }
  public static Id survey() {
    Kobentra_Integration__mdt config = settings();
    if (!config.Enabled__c || String.isBlank(config.Survey_Id__c))
      throw new KobentraException(
        'Native dispatch must be configured by an operator.'
      );
    Id survey;
    try {
      survey = Id.valueOf(config.Survey_Id__c);
    } catch (Exception error) {
      throw new KobentraException('Verify the configured survey identifier.');
    }
    if (survey.getSObjectType() != ArdiraSurvey__Survey__c.SObjectType)
      throw new KobentraException('Verify the configured survey identifier.');
    return survey;
  }
}
