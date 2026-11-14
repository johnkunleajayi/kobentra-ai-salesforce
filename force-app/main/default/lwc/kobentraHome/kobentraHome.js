import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import isGuest from "@salesforce/user/isGuest";
import { kobentraImages } from "./kobentraAssets";

export default class KobentraHome extends NavigationMixin(LightningElement) {
    @api profilePageName;
    @api workspacePageName;

    images = kobentraImages;

    get destinationMissing() {
        return !isGuest && !this.profilePageName;
    }

    get workspaceMissing() {
        return !isGuest && !this.workspacePageName;
    }

    get actionLabel() {
        return isGuest
            ? "Get started"
            : "Go to my account";
    }

    get isAuthenticated() {
        return !isGuest;
    }

    get logoUrl() {
        return this.images.logoLight;
    }

    start() {
        if (isGuest) {
            this.navigateToLogin();
            return;
        }

        if (this.profilePageName) {
            this.navigateToPage(this.profilePageName);
        }
    }

    workspace() {
        if (isGuest) {
            this.navigateToLogin();
            return;
        }

        if (this.workspacePageName) {
            this.navigateToPage(this.workspacePageName);
        }
    }

    navigateToLogin() {
        this[NavigationMixin.Navigate]({
            type: "comm__loginPage",
            attributes: {
                actionName: "login"
            }
        });
    }

    navigateToPage(pageName) {
        if (!pageName) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: pageName
            }
        });
    }
}
