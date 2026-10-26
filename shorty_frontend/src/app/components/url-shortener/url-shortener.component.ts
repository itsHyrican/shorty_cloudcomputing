import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import {
  AbstractControl,
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';

import { ShortUrlService } from '../../core/services/short-url.service';
import { ApiError, ShortUrl } from '../../models/short-url.model';
import { ShortUrlResultComponent } from '../short-url-result/short-url-result.component';

export interface TtlOption {
  readonly label: string;

  /** Lifetime in seconds; `null` falls back to the backend's default TTL. */
  readonly value: number | null;
}

const TTL_OPTIONS: readonly TtlOption[] = [
  { label: 'Standard (24 h)', value: null },
  { label: '1 Std.', value: 3_600 },
  { label: '6 Std.', value: 21_600 },
  { label: '1 Tag', value: 86_400 },
  { label: '7 Tage', value: 604_800 },
  { label: '30 Tage', value: 2_592_000 },
];

/**
 * Main interactive part of the landing page: collects the original URL and an
 * optional TTL, calls the backend and displays the created short link.
 */
@Component({
  selector: 'app-url-shortener',
  imports: [CommonModule, ReactiveFormsModule, ShortUrlResultComponent],
  templateUrl: './url-shortener.component.html',
})
export class UrlShortenerComponent {
  private readonly fb = inject(FormBuilder);
  private readonly shortUrlService = inject(ShortUrlService);

  protected readonly form = this.fb.group({
    url: new FormControl<string>(
      '',
      { nonNullable: true, validators: [Validators.required, UrlShortenerComponent.urlValidator] },
    ),
  });

  protected readonly ttlOptions = TTL_OPTIONS;

  /** Selected TTL preset; `null` means the backend default (24 hours). */
  protected readonly selectedTtl = signal<number | null>(null);

  protected selectTtl(value: number | null): void {
    this.selectedTtl.set(value);
  }

  protected readonly isSubmitting = signal(false);
  protected readonly result = signal<ShortUrl | null>(null);
  protected readonly error = signal<string | null>(null);

  /** Links created during this session, newest first (max. 5 entries). */
  protected readonly history = signal<ShortUrl[]>([]);

  protected get urlControl() {
    return this.form.controls.url;
  }

  /** Validates that the input looks like an absolute http(s) URL. */
  private static urlValidator(control: AbstractControl): ValidationErrors | null {
    const value = control.value as string;
    if (!value || !value.trim()) {
      // Empty values are reported by the required validator.
      return null;
    }
    return /^https?:\/\/\S+\.\S+/i.test(value.trim()) ? null : { invalidUrl: true };
  }

  protected submit(): void {
    if (this.form.invalid || this.isSubmitting()) {
      this.form.markAllAsTouched();
      return;
    }

    const url = (this.urlControl.value ?? '').trim();
    const ttlSeconds = this.selectedTtl() ?? undefined;

    this.isSubmitting.set(true);
    this.error.set(null);

    this.shortUrlService.create(url, ttlSeconds).subscribe({
      next: (shortUrl) => {
        this.result.set(shortUrl);
        this.history.update((entries) => [shortUrl, ...entries].slice(0, 5));
        this.urlControl.reset();
        this.selectedTtl.set(null);
        this.isSubmitting.set(false);
      },
      error: (err) => {
        this.error.set(this.toErrorMessage(err));
        this.isSubmitting.set(false);
      },
    });
  }

  /** Absolute address for a short path, used for the clickable links. */
  protected resolveUrl(shortUrlPath: string): string {
    return this.shortUrlService.resolveUrl(shortUrlPath);
  }

  protected formatExpiry(isoDate: string | null): string {
    if (!isoDate) {
      return 'unbegrenzt';
    }
    return new Date(isoDate).toLocaleString('de-DE', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });
  }

  private toErrorMessage(err: unknown): string {
    if (err instanceof HttpErrorResponse) {
      const response = err;
      const body = response.error as ApiError | undefined;
      if (body?.error) {
        return body.error;
      }
      if (response.status === 0) {
        return 'Der Shorty-Backend ist nicht erreichbar. Läuft er (docker compose up)?';
      }
    }
    return 'Die Kurz-URL konnte nicht erstellt werden. Bitte versuche es erneut.';
  }
}
