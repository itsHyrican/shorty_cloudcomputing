import { Component, inject, input, signal } from '@angular/core';

import { ShortUrlService } from '../../core/services/short-url.service';
import { ShortUrl } from '../../models/short-url.model';

/**
 * Displays a freshly created short link with its expiry and offers a
 * copy-to-clipboard button.
 */
@Component({
  selector: 'app-short-url-result',
  templateUrl: './short-url-result.component.html',
})
export class ShortUrlResultComponent {
  /** The newly created short link. */
  readonly shortUrl = input.required<ShortUrl>();

  private readonly shortUrlService = inject(ShortUrlService);

  protected readonly copied = signal(false);

  protected get absoluteUrl(): string {
    return this.shortUrlService.resolveUrl(this.shortUrl().shortUrl);
  }

  protected get createdLabel(): string {
    return this.formatDate(this.shortUrl().createdAt);
  }

  protected get expiryLabel(): string {
    const expiresAt = this.shortUrl().expiresAt;
    if (!expiresAt) {
      return 'unbegrenzt';
    }
    return this.formatDate(expiresAt);
  }

  protected copy(): void {
    if (!navigator.clipboard) {
      return;
    }
    navigator.clipboard
      .writeText(this.absoluteUrl)
      .then(() => {
        this.copied.set(true);
        setTimeout(() => this.copied.set(false), 2000);
      })
      .catch(() => {
        // Clipboard unavailable (e.g. insecure context) – ignore silently.
      });
  }

  private formatDate(isoDate: string): string {
    return new Date(isoDate).toLocaleString('de-DE', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });
  }
}
