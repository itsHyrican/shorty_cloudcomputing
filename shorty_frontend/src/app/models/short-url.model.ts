/** Mirrors the `ShortUrlResponse` DTO returned by the Shorty backend. */
export interface ShortUrl {
  /** Unique short code, e.g. "abc123". */
  code: string;

  /** Path of the shortened link, e.g. "/abc123". */
  shortUrl: string;

  /** The original URL that was shortened. */
  originalUrl: string;

  /** ISO date-time at which the link was created. */
  createdAt: string;

  /** ISO date-time at which the link expires; `null` means permanent. */
  expiresAt: string | null;
}

/** Request payload for `POST /api/shorturls`. */
export interface CreateShortUrlRequest {
  url: string;

  /** Optional lifetime in seconds; omitted falls back to the backend default TTL. */
  ttlSeconds?: number;
}

/** Error body returned by the backend (e.g. 400 Bad Request). */
export interface ApiError {
  error: string;
}
