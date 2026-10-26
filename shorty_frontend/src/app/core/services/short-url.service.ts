import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { CreateShortUrlRequest, ShortUrl } from '../../models/short-url.model';

/**
 * Talks to the Shorty backend API. All requests go through {@link HttpClient},
 * so the base URL can be adjusted per environment (see `src/environments`).
 */
@Injectable({ providedIn: 'root' })
export class ShortUrlService {
  private readonly http = inject(HttpClient);

  /** Base address of the backend without a trailing slash, e.g. "http://localhost:8080". */
  readonly baseUrl = environment.apiUrl.replace(/\/+$/, '');

  /** Creates a new short URL via `POST /api/shorturls`. */
  create(url: string, ttlSeconds?: number): Observable<ShortUrl> {
    const request: CreateShortUrlRequest = { url };
    if (ttlSeconds !== undefined && ttlSeconds > 0) {
      request.ttlSeconds = ttlSeconds;
    }
    return this.http.post<ShortUrl>(`${this.baseUrl}/api/shorturls`, request);
  }

  /** Builds the absolute address for a short path like "/abc123". */
  resolveUrl(shortUrlPath: string): string {
    const path = shortUrlPath.startsWith('/') ? shortUrlPath : `/${shortUrlPath}`;
    return `${this.baseUrl}${path}`;
  }
}
