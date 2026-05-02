import { LightningElement, api } from 'lwc';

export default class HcDirectoryResultsRenderer extends LightningElement {
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

    get rows() {
        const r = this.payloadObj?.rows;
        return Array.isArray(r) ? r : [];
    }

    get cards() {
        return this.rows.map((row, idx) => ({
            key: `dir-${idx}`,
            title: row.providerName || 'Provider',
            subtitle: row.facilityName || 'Facility',
            line: (row.line || '').trim()
        }));
    }

    get hasRows() {
        return this.cards.length > 0;
    }
}