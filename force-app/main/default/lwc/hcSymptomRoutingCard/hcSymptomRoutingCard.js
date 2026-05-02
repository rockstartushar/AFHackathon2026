import { LightningElement, api } from 'lwc';

export default class HcSymptomRoutingCard extends LightningElement {
    /** Bound Custom Lightning Type instance (HCSymptomRoutingUiModel). */
    @api value;

    get payloadObj() {
        const raw = this.value?.payload;
        if (!raw || typeof raw !== 'string') {
            return null;
        }
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    get specialtyTitle() {
        const s = this.payloadObj?.recommendedSpecialty;
        return s && String(s).trim() ? String(s).trim() : 'Care navigation';
    }

    get summaryText() {
        return this.payloadObj?.routingSummary || '';
    }

    get disclaimerText() {
        return this.payloadObj?.disclaimer || '';
    }

    get matchFound() {
        return this.payloadObj?.matchFound === true;
    }
}
