import { createElement } from "lwc";
import KobentraOnboarding from "c/kobentraOnboarding";
import getProfile from "@salesforce/apex/KobentraController.getProfile";
import saveProfile from "@salesforce/apex/KobentraController.saveProfile";
jest.mock("@salesforce/user/isGuest", () => ({ default: false }), {
  virtual: true
});
jest.mock(
  "@salesforce/apex/KobentraController.getProfile",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.saveProfile",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});
test("loads provisioned business fields and saves no client identity", async () => {
  getProfile.mockResolvedValue({
    name: "Fictional business",
    country: "Nigeria",
    industry: "Manufacturing",
    industries: [],
    summary: "Food producer",
    lastName: "Owner",
    email: "owner@example.invalid"
  });
  saveProfile.mockResolvedValue();
  const element = createElement("c-kobentra-onboarding", {
    is: KobentraOnboarding
  });
  document.body.appendChild(element);
  await flush();
  expect(getProfile).toHaveBeenCalledTimes(1);
  const inputs = element.shadowRoot.querySelectorAll(
    "lightning-input,lightning-combobox,lightning-textarea"
  );
  inputs.forEach((input) => {
    input.reportValidity = jest.fn(() => true);
  });
  const target = [...inputs].find((input) => input.name === "targetCountry");
  target.dispatchEvent(
    new CustomEvent("change", { detail: { value: "Ghana" } })
  );
  [...element.shadowRoot.querySelectorAll("lightning-button")]
    .find((button) => button.label === "Save business profile")
    .click();
  await flush();
  expect(saveProfile).toHaveBeenCalledWith({
    input: expect.objectContaining({
      name: "Fictional business",
      targetCountry: "Ghana"
    })
  });
  expect(saveProfile.mock.calls[0][0].input.accountId).toBeUndefined();
  expect(
    element.shadowRoot.querySelector('[role="status"]').textContent
  ).toContain("saved");
});
test("shows access error and retry", async () => {
  getProfile.mockRejectedValue({
    body: { message: "Business membership is unavailable." }
  });
  const element = createElement("c-kobentra-onboarding", {
    is: KobentraOnboarding
  });
  document.body.appendChild(element);
  await flush();
  expect(
    element.shadowRoot.querySelector('[role="alert"]').textContent
  ).toContain("membership");
  expect(
    [...element.shadowRoot.querySelectorAll("lightning-button")].some(
      (button) => button.label === "Retry loading"
    )
  ).toBe(true);
});
