# syntax=docker/dockerfile:1

# ---------- Build stage ----------
FROM node:24-alpine AS build
WORKDIR /src

# Install dependencies first for better layer caching.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# The backend base URL is baked into the client bundle at build time
# (src/environments/environment.ts), so it is injected here as a build arg.
ARG API_URL=http://localhost:8080
RUN sed -i "s|^  apiUrl: .*|  apiUrl: '${API_URL}',|" src/environments/environment.ts \
    && npx ng build --configuration production

# ---------- Runtime stage ----------
FROM node:24-alpine AS runtime
ENV NODE_ENV=production \
    PORT=4000
WORKDIR /app

# The SSR server needs the built app plus its production dependencies.
COPY --from=build /src/dist/shorty_frontend ./dist/shorty_frontend
COPY --from=build /src/package.json ./package.json
RUN npm install --omit=dev

EXPOSE 4000
CMD ["node", "dist/shorty_frontend/server/server.mjs"]
