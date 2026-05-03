import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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
            const line = row.line || '';
            const parts = [title, subtitle, line].filter((p) => p && String(p).trim());
            return {
                key: `fac-${idx}`,
                title,
                subtitle,
                line,
                copyText: parts.length ? parts.join(' — ') : title
            };
        });
    }

    get hasRows() {
        return this.cards.length > 0;
    }

    get showError() {
        return !this.success && this.errorMessage;
    }

    handleCardCopy(event) {
        const text = event.currentTarget?.dataset?.copytext || '';
        this.copyToClipboard(text);
    }

    handleCardKeydown(event) {
        const k = event.key;
        if (k === 'Enter' || k === ' ') {
            event.preventDefault();
            this.handleCardCopy(event);
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
}
