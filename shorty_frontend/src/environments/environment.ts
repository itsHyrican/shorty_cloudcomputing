/**
 * Production environment values.
 * `apiUrl` points at the deployed backend host; locally the backend
 * runs via Docker Compose on port 8080.
 */
export const environment = {
  production: true,
  apiUrl: 'http://localhost:8080',
} as const;
