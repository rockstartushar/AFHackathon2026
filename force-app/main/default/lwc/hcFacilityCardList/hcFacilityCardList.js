import { LightningElement, api } from 'lwc';

export default class HcFacilityCardList extends LightningElement {
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
        const p = this.payloadObj;
        if (p && typeof p.success === 'boolean') {
            return p.success;
        }
        return true;
    }

    get errorMessage() {
        const p = this.payloadObj;
        return p && typeof p.message === 'string' ? p.message : '';
    }

    get rows() {
        const r = this.payloadObj?.rows;
        return Array.isArray(r) ? r : [];
    }

    get cards() {
        return this.rows.map((row, idx) => {
            const title = row.facilityName || 'Facility';
            const fromLine = (row.line || '').replace(/^-\s*/, '').trim();
            const subtitle =
                fromLine && fromLine !== title ? fromLine : '';
            return {
                key: `fac-${idx}`,
                title,
                subtitle,
                line: row.line || ''
            };
        });
    }

    get hasRows() {
        return this.cards.length > 0;
    }

    get showError() {
        return !this.success && this.errorMessage;
    }
}