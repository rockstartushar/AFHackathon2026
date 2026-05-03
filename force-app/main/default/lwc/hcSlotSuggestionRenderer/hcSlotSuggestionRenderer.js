import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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
     * Selection state only when the model bound a plain string (chosen slot label).
     * Avoid treating booleans or empty objects as "selection" (prevents "Selected: true" in chat).
     */
    get isSelection() {
        const v = this.value;
        if (v == null || v === '') {
            return false;
        }
        if (typeof v === 'string') {
            return v.trim().length > 0;
        }
        return false;
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
        const fac = this.facilityLabel;
        const d = this.dateLabel;
        return slots.map((s, idx) => {
            const label = s.label || `${s.start} – ${s.end}`;
            const parts = [fac, d, label].filter((p) => p && String(p).trim());
            return {
                key: `slot-${idx}`,
                label,
                copyText: parts.join(' — ')
            };
        });
    }

    handleSlotCopy(event) {
        const text = event.currentTarget?.dataset?.copytext || '';
        this.copyToClipboard(text);
    }

    handleSlotKeydown(event) {
        const k = event.key;
        if (k === 'Enter' || k === ' ') {
            event.preventDefault();
            this.handleSlotCopy(event);
        }
    }

    async copyToClipboard(text) {
        if (!text) {
            return;
        }
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(text);
            } else {
                const ta = document.createElement('textarea');
                ta.value = text;
                ta.setAttribute('readonly', '');
                ta.style.position = 'absolute';
                ta.style.left = '-9999px';
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Copied',
                    message: 'Paste into the message box to confirm your choice.',
                    variant: 'success',
                    mode: 'dismissable'
                })
            );
        } catch (err) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Copy failed',
                    message: 'Select the text manually if needed.',
                    variant: 'warning',
                    mode: 'dismissable'
                })
            );
        }
    }

    get hasSlots() {
        return this.slotRows.length > 0;
    }

    get emptyMessage() {
        return this.hasSlots ? '' : 'No open times for this date.';
    }
}