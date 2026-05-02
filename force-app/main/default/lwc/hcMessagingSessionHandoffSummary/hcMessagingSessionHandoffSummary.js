import { LightningElement, api } from 'lwc';
import getHandoffSummary from '@salesforce/apex/HC_MessagingSessionSummaryController.getHandoffSummary';

export default class HcMessagingSessionHandoffSummary extends LightningElement {
    @api recordId;

    loading = false;
    summaryText = '';
    error = '';
    hint = '';

    connectedCallback() {
        this.load();
    }

    get hasSummary() {
        return !this.loading && this.summaryText;
    }

    get showHint() {
        return !this.loading && this.hint;
    }

    handleRefresh() {
        this.load();
    }

    async load() {
        if (!this.recordId) {
            this.error = 'No record context.';
            return;
        }
        this.loading = true;
        this.error = '';
        this.hint = '';
        try {
            const r = await getHandoffSummary({ messagingSessionId: this.recordId });
            this.summaryText = r.summaryText || '';
            if (r.mode === 'models_api') {
                this.hint =
                    r.message ||
                    'Generated with Einstein Models API. You can add Flex template HC_Messaging_Session_Handoff_Summary in Prompt Builder for managed wording.';
            } else if (r.mode === 'fallback') {
                this.hint =
                    r.message ||
                    'Showing a short transcript excerpt. Enable Einstein Generative AI or add the Flex prompt for a full AI summary.';
            } else if (r.message) {
                this.hint = r.message;
            }
            if (!r.success && r.message) {
                this.error = r.message;
            }
        } catch (e) {
            this.reduceError(e);
            this.summaryText = '';
        } finally {
            this.loading = false;
        }
    }

    reduceError(err) {
        this.error = err?.body?.message || err?.message || 'Could not load summary.';
    }
}
