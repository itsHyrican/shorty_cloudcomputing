/**
 * Development environment values. During development the backend
 * runs via Docker Compose on port 8080.
 */
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080',
} as const;
