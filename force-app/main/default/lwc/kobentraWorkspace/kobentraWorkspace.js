import { LightningElement } from "lwc";
import isGuest from "@salesforce/user/isGuest";
import getWorkspace from "@salesforce/apex/KobentraController.getWorkspace";
import requestAssessment from "@salesforce/apex/KobentraController.requestAssessment";
import createOpportunity from "@salesforce/apex/KobentraController.createOpportunity";
import setPublication from "@salesforce/apex/KobentraController.setPublication";
import expressInterest from "@salesforce/apex/KobentraController.expressInterest";
import decideInterest from "@salesforce/apex/KobentraController.decideInterest";
const options = (values) => values.map((value) => ({ label: value, value }));
export default class KobentraWorkspace extends LightningElement {
  guest = isGuest;
  data;
  busy = false;
  error;
  success;
  form = { type: "Distribution", stage: "Exploring" };
  types = options(["Distribution", "Supply", "Partnership", "Investment"]);
  stages = options(["Exploring", "Conversation", "Closed"]);
  connectedCallback() {
    if (!this.guest) this.load();
  }
  get opportunities() {
    return (this.data?.opportunities || []).map((row) => ({
      ...row,
      action: row.publication === "Published" ? "Draft" : "Published",
      actionLabel: row.publication === "Published" ? "Unpublish" : "Publish"
    }));
  }
  get discovery() {
    return this.data?.discovery || [];
  }
  get interests() {
    return (this.data?.interests || []).map((row) => ({
      ...row,
      canDecide: row.incoming && row.status === "Requested",
      canWithdraw: !row.incoming && row.status === "Requested"
    }));
  }
  get requestDisabled() {
    return this.busy || this.data?.assessment?.status !== "Not requested";
  }
  get assessmentMessage() {
    switch (this.data?.assessment?.status) {
      case "Requested":
        return "Request saved. An internal operator dispatches your native SurveyVista invitation.";
      case "Assigned":
        return "Your assigned assessment is awaiting verified completion. Check your email for the SurveyVista invitation.";
      case "Completed":
        return "Completion verified for your assigned survey. You can publish opportunities and explore your market.";
      case "Review":
        return "This assessment requires an internal operator to review its result linkage.";
      default:
        return "Complete your profile, then request your assessment. Completion must be verified before publication.";
    }
  }
  async load() {
    this.busy = true;
    this.error = undefined;
    try {
      this.data = await getWorkspace();
    } catch (error) {
      this.data = undefined;
      this.error =
        error?.body?.message ||
        "Your workspace could not be loaded. Check access and retry.";
    } finally {
      this.busy = false;
    }
  }
  async perform(action, success) {
    if (this.busy) return;
    this.busy = true;
    this.error = undefined;
    this.success = undefined;
    try {
      await action();
      this.success = success;
      await this.load();
    } catch (error) {
      this.error =
        error?.body?.message ||
        "This action could not be completed. Check access and retry.";
    } finally {
      this.busy = false;
    }
  }
  request() {
    this.perform(
      () => requestAssessment(),
      "Assessment request saved. Repeating the request does not create another assignment."
    );
  }
  change(event) {
    this.form = { ...this.form, [event.target.name]: event.detail.value };
  }
  save() {
    if (
      ![...this.template.querySelectorAll("[data-draft]")]
        .map((input) => input.reportValidity())
        .every(Boolean)
    )
      return;
    this.perform(
      () => createOpportunity({ input: { ...this.form } }),
      "Private draft saved. Review it, then publish explicitly."
    );
  }
  publish(event) {
    const { id, state } = event.currentTarget.dataset;
    this.perform(
      () => setPublication({ opportunityId: id, state }),
      state === "Published"
        ? "Opportunity published."
        : "Opportunity returned to a private draft."
    );
  }
  interest(event) {
    const opportunityId = event.currentTarget.dataset.id;
    this.perform(
      () => expressInterest({ opportunityId }),
      "Interest recorded. Private contact details remain protected."
    );
  }
  decision(event) {
    const { id, decision } = event.currentTarget.dataset;
    this.perform(
      () => decideInterest({ interestId: id, decision }),
      "Interest decision saved. No contact information has been released."
    );
  }
}
