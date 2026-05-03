import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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
        return this.rows.map((row, idx) => {
            const title = row.providerName || 'Provider';
            const subtitle = row.facilityName || 'Facility';
            const line = (row.line || '').trim();
            const parts = [title, subtitle, line].filter((p) => p && String(p).trim());
            return {
                key: `dir-${idx}`,
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
