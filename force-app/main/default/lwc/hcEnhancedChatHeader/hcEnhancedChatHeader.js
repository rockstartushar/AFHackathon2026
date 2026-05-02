import { LightningElement, api } from 'lwc';
import {
    dispatchMessagingEvent,
    assignMessagingEventHandler,
    MESSAGING_EVENT
} from 'lightningsnapin/eventStore';
import brandLogo from '@salesforce/resourceUrl/hconcogloballogo';

/**
 * Custom conversation header for Enhanced Web Chat v2.
 * @see https://developer.salesforce.com/docs/service/messaging-web/guide/customize-header.html
 */
export default class HcEnhancedChatHeader extends LightningElement {
    /** Deployment configuration (labels, branding) from Embedded Service. */
    @api configuration = {};

    /** Conversation lifecycle hint from the messaging client. */
    @api conversationStatus;

    headerTitle = 'Onco Global';
    logoSrc = brandLogo;
    logoFailed = false;

    get displayTitle() {
        return this.headerTitle || 'Chat';
    }

    get showLogo() {
        return !!this.logoSrc && !this.logoFailed;
    }

    connectedCallback() {
        assignMessagingEventHandler(MESSAGING_EVENT.UPDATE_HEADER_TEXT, (data) => {
            if (data && typeof data.text === 'string' && data.text.trim()) {
                this.headerTitle = data.text;
            }
        });
    }

    handleLogoError() {
        this.logoFailed = true;
    }

    handleMinimize() {
        dispatchMessagingEvent(MESSAGING_EVENT.MINIMIZE_BUTTON_CLICK, {});
    }

    /**
     * Close hides the chat surface; some deployments only react when the conversation
     * close event is fired as well (see Salesforce Enhanced Web Chat header samples).
     */
    handleClose() {
        dispatchMessagingEvent(MESSAGING_EVENT.CLOSE_CONTAINER, {});
        dispatchMessagingEvent(MESSAGING_EVENT.CLOSE_CONVERSATION, {});
    }
}