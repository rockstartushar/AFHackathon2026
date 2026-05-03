import { LightningElement, api } from 'lwc';

export default class HcSlotSuggestionRenderer extends LightningElement {
    _internalValue;
    _readOnly = false;

    /** 
     * Mandatory for Agentforce Input components to handle 
     * the state transition after a user response. 
     */
    @api 
    get readOnly() {
        return this._readOnly;
    }
    set readOnly(val) {
        this._readOnly = val;
    }

    @api 
    get value() {
        return this._internalValue;
    }
    set value(val) {
        this._internalValue = val;
    }

    /**
     * Determines if the current value is the raw payload 
     * (for rendering slots) or the final selection string.
     */
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

    /**
     * Used in HTML to show a "Selection Confirmed" state 
     * instead of the "Unable to display slots" error.
     */
    get isSelection() {
        return this.value && !this.payloadObj;
    }

    get facilityLabel() {
        return this.payloadObj?.facilityName || 'Selected facility';
    }

    get dateLabel() {
        return this.payloadObj?.date || '';
    }

    get slotRows() {
        const slots = this.payloadObj?.slots;
        if (!Array.isArray(slots)) {
            return [];
        }
        return slots.map((s, idx) => ({
            key: `slot-${idx}`,
            label: s.label || `${s.start} – ${s.end}`,
        }));
    }

    get hasSlots() {
        return this.slotRows.length > 0;
    }

    get emptyMessage() {
        return this.hasSlots ? '' : 'No open times for this date.';
    }
}