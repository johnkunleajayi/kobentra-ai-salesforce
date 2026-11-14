import { createElement } from "lwc";
import KobentraWorkspace from "c/kobentraWorkspace";
import getWorkspace from "@salesforce/apex/KobentraController.getWorkspace";
import requestAssessment from "@salesforce/apex/KobentraController.requestAssessment";
import expressInterest from "@salesforce/apex/KobentraController.expressInterest";
jest.mock("@salesforce/user/isGuest", () => ({ default: false }), {
  virtual: true
});
jest.mock(
  "@salesforce/apex/KobentraController.getWorkspace",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.requestAssessment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.createOpportunity",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.setPublication",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.expressInterest",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KobentraController.decideInterest",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());
const base = {
  profile: {
    name: "Fictional business",
    country: "Ghana",
    industry: "Manufacturing"
  },
  assessment: { status: "Not requested" },
  markets: [],
  opportunities: [],
  discovery: [],
  interests: []
};
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});
test("shows truthful empty state and durable request feedback", async () => {
  getWorkspace.mockResolvedValue(base);
  requestAssessment.mockResolvedValue();
  const element = createElement("c-kobentra-workspace", {
    is: KobentraWorkspace
  });
  document.body.appendChild(element);
  await flush();
  expect(element.shadowRoot.textContent).toContain("No visible opportunities");
  [...element.shadowRoot.querySelectorAll("lightning-button")]
    .find((button) => button.label === "Request assessment")
    .click();
  await flush();
  expect(requestAssessment).toHaveBeenCalledTimes(1);
  expect(getWorkspace).toHaveBeenCalledTimes(2);
  expect(
    element.shadowRoot.querySelector('[role="status"]').textContent
  ).toContain("request saved");
});
test("renders published projection and sends only the selected opportunity", async () => {
  getWorkspace.mockResolvedValue({
    ...base,
    assessment: { status: "Completed" },
    discovery: [
      {
        id: "public-opportunity",
        title: "Food distribution",
        businessName: "Fictional producer",
        businessCountry: "Nigeria",
        country: "Ghana",
        category: "Food",
        summary: "Published description",
        reason: "Published for your business country."
      }
    ]
  });
  expressInterest.mockResolvedValue();
  const element = createElement("c-kobentra-workspace", {
    is: KobentraWorkspace
  });
  document.body.appendChild(element);
  await flush();
  expect(element.shadowRoot.textContent).toContain("Food distribution");
  [...element.shadowRoot.querySelectorAll("lightning-button")]
    .find((button) => button.label === "Express interest")
    .click();
  await flush();
  expect(expressInterest).toHaveBeenCalledWith({
    opportunityId: "public-opportunity"
  });
  expect(element.shadowRoot.textContent).toContain(
    "Private contact details remain protected"
  );
});
test("fails closed on access errors", async () => {
  getWorkspace.mockRejectedValue({
    body: { message: "Business access is suspended." }
  });
  const element = createElement("c-kobentra-workspace", {
    is: KobentraWorkspace
  });
  document.body.appendChild(element);
  await flush();
  expect(
    element.shadowRoot.querySelector('[role="alert"]').textContent
  ).toContain("suspended");
  expect(
    [...element.shadowRoot.querySelectorAll("lightning-button")].some(
      (button) => button.label === "Express interest"
    )
  ).toBe(false);
});
