import { LightningElement } from "lwc";
import isGuest from "@salesforce/user/isGuest";
import getProfile from "@salesforce/apex/KobentraController.getProfile";
import saveProfile from "@salesforce/apex/KobentraController.saveProfile";
const message = (error) =>
  error?.body?.message ||
  "We could not complete this action. Check access and try again.";
export default class KobentraOnboarding extends LightningElement {
  profile = {};
  industries = [];
  busy = false;
  error;
  success;
  guest = isGuest;
  interests = [
    "Find distributors",
    "Find suppliers",
    "Find buyers",
    "Strategic partners",
    "Investment"
  ].map((value) => ({ label: value, value }));
  connectedCallback() {
    if (!this.guest) this.load();
  }
  async load() {
    this.busy = true;
    try {
      const data = await getProfile();
      this.profile = { ...data };
      this.industries = data.industries;
      this.error = undefined;
    } catch (error) {
      this.error = message(error);
    } finally {
      this.busy = false;
    }
  }
  change(event) {
    this.profile = { ...this.profile, [event.target.name]: event.detail.value };
    this.success = undefined;
  }
  async save() {
    const valid = [
      ...this.template.querySelectorAll(
        "lightning-input,lightning-combobox,lightning-textarea"
      )
    ]
      .map((input) => input.reportValidity())
      .every(Boolean);
    if (!valid) return;
    this.busy = true;
    this.error = undefined;
    this.success = undefined;
    const {
      name,
      country,
      industry,
      summary,
      firstName,
      lastName,
      email,
      targetCountry,
      intent
    } = this.profile;
    try {
      await saveProfile({
        input: {
          name,
          country,
          industry,
          summary,
          firstName,
          lastName,
          email,
          targetCountry,
          intent
        }
      });
      this.success =
        "Business profile and market preference saved. Open your workspace to request your assessment.";
    } catch (error) {
      this.error = message(error);
    } finally {
      this.busy = false;
    }
  }
}
