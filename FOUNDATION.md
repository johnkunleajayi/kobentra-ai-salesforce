# Kobentra Salesforce-native foundation — Milestone 1

Local Salesforce DX source only. Nothing has been deployed, scheduled, assigned or published. Existing Aura sites, managed packages and the active Lead Flow are preserved. The React/FastAPI project remains read-only reference.

## Model and access

- **Account** is the business. `Kobentra_Access__c` is Active/Suspended; blank legacy values are not treated as a suspension. A Contact belongs to that Account; authenticated Experience users derive their membership exclusively from `User.ContactId → Contact.AccountId`. No client-supplied business ID is trusted. Multiple provisioned contacts/users can belong to one business.
- **Kobentra_Market_Preference__c** holds a target country, partnership intent and unique normalized business/country/intent key.
- **Kobentra_Assessment__c** holds a private, unique business/version request, requesting Contact, Lead linkage, result identifier and verified completion date. Business users cannot read Lead/result/contact linkage fields or edit assessment state.
- **Kobentra_Opportunity__c** holds structured opportunity details, independent commercial stage, Draft/Published state and explicit publication date/business-display snapshots. Editing published content returns it to Draft. A new record cannot start Published. Publication requires completed assessment, industry/country and a market preference.
- **Kobentra_Interest__c** records a unique business/opportunity interest, safe business-name/title snapshots and Requested/Accepted/Declined/Withdrawn state. Receiving business is derived from the immutable opportunity business, avoiding an unnecessary private cross-tenant Account lookup. Only the receiver can accept/decline; only the sender can withdraw a pending interest. No contact release or agreement is implied.
- All four custom objects use Private internal/external sharing. Controllers/services use `with sharing`, explicit membership checks and user-mode queries/DML. Trigger guards also enforce tenant ownership, immutable participants, publication and assessment rules on direct record writes. No delete permissions are granted.
- The sole elevated operation inserts an interest **sharing row**, granting Edit only to the exact owner of the published opportunity the member explicitly selected. It does not query or mutate private business, Contact or assessment data in system mode. The receiving business's other users do not automatically receive this grant in this milestone.
- Opportunity discovery returns a deliberately limited DTO, not arbitrary sObjects, and only published active businesses targeting the caller's declared country. No matching percentage, independent identity verification or readiness score is invented. Private Accounts, Contacts, drafts and assessments are not shared for discovery.

## SurveyVista integration

1. A business member creates one durable assessment request per configured version. Account row locking plus a unique key prevents repeat assignment creation.
2. An **internal operator** invokes `KobentraAssessmentDispatch` (or the optional scheduler). It locks requests, creates one Lead per unlinked request and sets the existing `Kobentra_Assessment_Requested__c` checkbox. The requesting Contact's real email/last name and the existing Account profile supply required information. Missing information fails without fabrication.
3. The preserved existing Flow creates the native SurveyVista result and invitation using its existing survey reference. Assigned means Lead creation/Flow transaction succeeded, **not proof of email delivery**.
4. `KobentraAssessmentReconcile` queries results for the exact linked Lead and configured survey. Only one matching Completed result with a completion timestamp no earlier than the request qualifies. Ambiguous results become Review; incomplete/mismatched results do not qualify. Repeated completion checks preserve the result.
5. Lead creation and request linkage share one Salesforce transaction. Failures roll back together. Operators may safely repeat dispatch; linked requests are skipped. There is no external REST call or OAuth credential in this native application.
6. `KobentraAssessmentScheduler` is source only: at most ten Requested and ten Assigned records per run, in one transaction. One invalid record can roll back that batch; operators must correct missing data or inspect Review records. No background job has been scheduled. Workspace refresh retrieves reconciled state; browser polling/answer ingestion/readiness scoring are not implemented in this milestone.

`Kobentra_Integration.Default` is deliberately disabled with a blank survey identifier. An operator must copy the verified existing Flow's survey reference into configuration and enable it **after deployment review**. No record IDs are hardcoded in new Apex. Changing Version creates a new qualification cycle; do not change it casually.

## Org observations and required manual configuration

Read-only inspection found API v68.0 available, project source API64.0, Flow API68.0, unused Customer Community Plus/Plus Login licenses, and both corresponding profiles. Account, Contact, Lead and SurveyVista results have Private external sharing. No SharingSet was returned. This does **not** prove external login, self-registration or business record sharing is configured.

Before a controlled user test:

1. Use role-capable **Customer Community Plus User** (or Plus Login after separate validation), not an assumed high-volume license. Confirm Experience membership/profile access on the new **Kobentra AI LWR** site only. Preserve both live Aura sites. Do not enable guest record access or expose these Apex methods to guests.
2. Provision one internal Account owner with a role, the business Account, its Contact and the external User linked to that Contact. Assign `Kobentra_Business_User` only to approved authenticated members. There is no public self-registration/provisioning workflow in this milestone; onboarding updates existing Account/Contact records rather than duplicating them.
3. Grant that user **Edit on their own Account and own Contact only**, using the supported role-based/manual sharing configuration for the selected license. For multiple members of one Account, configure appropriate own-business custom-record sharing without sharing across businesses. Permission sets grant CRUD/FLS, **not record access**. Do not assume a SharingSet is available for every external license. Validate actual access with two independent external users before launch.
4. The public group `Kobentra_Business_Users` is delivered empty. Add only intended authenticated business users. The criteria rule shares only explicitly Published opportunity records Read to that group. Never add guest users or broadly share Accounts/Contacts/assessments. Unpublication removes criteria sharing asynchronously under Salesforce sharing recalculation; discovery immediately filters Draft regardless of stale sharing grants.
5. Assign `Kobentra_Assessment_Operator` to an internal licensed user, plus the installed SurveyVista package's genuine required license/permissions. Add **only these internal operators** to the initially empty `Kobentra_Assessment_Operators` group: its assessment sharing rule grants Edit on the private requests so user-mode processing can update them. Verify the four result fields and existing Lead checkbox are readable/writable as appropriate. Do not assign this set or group to external users. Actual package/license compatibility and user-mode field access must be checked during deployment validation.
6. Configure the integration metadata as above. After separate approval, dispatch/reconcile through the invocable Apex actions in an internal-only automation, or schedule `KobentraAssessmentScheduler` under the operator. No new Flow or scheduled job is created automatically.
7. Add `kobentraHome`, `kobentraOnboarding`, `kobentraWorkspace` to new LWR pages in Experience Builder. Set Home's two properties to the **actual Builder page API names**. They are intentionally blank instead of guessing routes. The components support `lightningCommunity__Page` and `lightningCommunity__Default`. Preview desktop/mobile and keyboard behavior before publishing; do not publish automatically.

Suspension blocks tenant API operations and excludes opportunities from discovery through a live Account-derived availability formula. It does not retroactively erase already disclosed published information. Account/Contact field edits do not silently synchronize previous Leads; each new assessment version snapshots the then-current requesting contact/profile.

## Validation and controlled deployment (review only)

```powershell
Set-Location C:\kobentra-ai
npm run lint
npm run test:unit -- -- --runInBand
# Requires explicit approval: server-side compile and Apex tests, without committing metadata.
sf project deploy validate --manifest manifest/kobentra-foundation.xml --target-org KobentraAI --api-version 68.0 --test-level RunSpecifiedTests --tests KobentraFoundationTest --tests KobentraAssessmentTest --tests KobentraProfileTest
# Only after approval and successful validation:
sf project deploy start --manifest manifest/kobentra-foundation.xml --target-org KobentraAI --api-version 68.0 --test-level RunSpecifiedTests --tests KobentraFoundationTest --tests KobentraAssessmentTest --tests KobentraProfileTest
```

The manifest excludes the existing Flow, all site/network metadata and managed-package definitions. Package object/field references are dependencies, not replacements. Apex tests use isolated test records and a gateway fake that explicitly clears the invitation checkbox before inserting any test Lead. No test creates a real invitation or modifies existing surveys. Tests depend on the observed Plus profile/license and explicit permission sets; run them in the target validation context before claiming Salesforce execution success.

Local formatting parses Apex syntax but is **not** the Salesforce compiler, license verification or an org security test. LWC Jest mocks Apex; it does not prove deployed LWR, browser, sharing-rule recalculation or email delivery behavior.

## Next milestone

Deploy and validate two separately provisioned businesses, actual record sharing, invitation delivery, result verification, explicit opportunity publication and recipient interest decisions. Then add managed account-user provisioning/self-registration only after license/security design approval, multi-member recipient access, focused background-job recovery/status, and verified SurveyVista answer ingestion/readiness logic. Do not port the old application wholesale or invent package APIs. EventSpark remains installed and untouched; event-to-business networking can be investigated later only against documented capabilities.
