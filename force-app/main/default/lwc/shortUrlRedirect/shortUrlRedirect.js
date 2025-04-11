import { LightningElement } from 'lwc';
import findLongUrl from '@salesforce/apex/ShortUrlRedirectController.findLongUrl';

export default class ShortUrlRedirect extends LightningElement {
    errorMessage;

    connectedCallback() {
        const path = window.location.pathname;
        const parts = path.split('/');
        const shortCode = parts[parts.length - 1];
        this.redirect(shortCode);
    }

    async redirect(code) {
        try {
            const url = await findLongUrl({ shortCode: code });
            if (url) {
                window.location.href = url;
            } else {
                this.errorMessage = 'Unknown destination.';
            }
        } catch (e) {
            console.error('Redirect failed', e);
            this.errorMessage = e?.body?.message || 'Short URL not found.';
        }
    }
}
