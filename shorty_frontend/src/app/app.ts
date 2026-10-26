import { Component } from '@angular/core';

import { UrlShortenerComponent } from './components/url-shortener/url-shortener.component';

/** Landing page shell of the Shorty URL shortener. */
@Component({
  selector: 'app-root',
  imports: [UrlShortenerComponent],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {}
