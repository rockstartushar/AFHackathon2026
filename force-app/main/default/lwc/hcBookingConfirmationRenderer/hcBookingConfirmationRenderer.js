import { LightningElement, api } from 'lwc';

export default class HcBookingConfirmationRenderer extends LightningElement {
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

    get success() {
        return this.payloadObj?.success === true;
    }

    get headline() {
        return this.payloadObj?.headline || '';
    }

    get detailMessage() {
        return this.payloadObj?.message || '';
    }

    get facilityName() {
        return this.payloadObj?.facilityName || '';
    }

    get subject() {
        return this.payloadObj?.subject || '';
    }

    get operation() {
        return this.payloadObj?.operation || '';
    }

    get schedLabel() {
        const s = this.payloadObj?.schedStart;
        const e = this.payloadObj?.schedEnd;
        if (!s || !e) {
            return '';
        }
        try {
            const ds = new Date(s);
            const de = new Date(e);
            return `${ds.toLocaleString()} – ${de.toLocaleString()}`;
        } catch (err) {
            return `${s} – ${e}`;
        }
    }

    get showSchedule() {
        return !!(this.payloadObj?.schedStart && this.payloadObj?.schedEnd);
    }

    get showFacilityLine() {
        return !!this.facilityName;
    }

    get showSubject() {
        return !!this.subject;
    }

    get successClass() {
        return this.success ? 'hc-book-card hc-book-ok' : 'hc-book-card hc-book-err';
    }
}