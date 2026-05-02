import { LightningElement, api } from 'lwc';

export default class HcCoveragePrepAccordion extends LightningElement {
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

    get sections() {
        const s = this.payloadObj?.sections;
        if (!Array.isArray(s)) {
            return [];
        }
        return s.map((sec, idx) => {
            const rawItems = Array.isArray(sec.items) ? sec.items : [];
            const items = rawItems.map((text, j) => ({
                key: `sec-${idx}-item-${j}`,
                text
            }));
            return {
                key: `sec-${idx}`,
                title: sec.title || 'Section',
                items
            };
        });
    }

    get hasSections() {
        return this.sections.length > 0;
    }
}