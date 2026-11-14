import { createElement } from "lwc";
import KobentraHome from "c/kobentraHome";
jest.mock("@salesforce/user/isGuest", () => ({ default: true }), {
  virtual: true
});
test("public home describes the journey without record access", () => {
  const element = createElement("c-kobentra-home", { is: KobentraHome });
  document.body.appendChild(element);
  expect(element.shadowRoot.textContent).toContain("Illustrative journey");
  expect(element.shadowRoot.textContent).toContain(
    "Public self-registration is not enabled"
  );
  expect(element.shadowRoot.querySelector("lightning-button").disabled).toBe(
    false
  );
  document.body.removeChild(element);
});
