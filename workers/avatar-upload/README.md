# winklo-avatar-upload

Cloudflare Worker for authenticated avatar uploads to R2 (`PUT /v1/avatar` with Firebase ID token verification).

## Prerequisites

- [Node.js](https://nodejs.org/) (LTS)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) (installed via `npm install` in this directory)
- Cloudflare account with Workers and R2 enabled

## One-time setup

1. **Create the R2 bucket** (name must match `wrangler.toml`):

   ```bash
   npx wrangler r2 bucket create winklo-avatars
   ```

2. **Enable public access** for the bucket in the Cloudflare dashboard (R2 → bucket → Settings → Public access / `r2.dev` subdomain). Copy the public base URL (e.g. `https://pub-xxxxx.r2.dev`).

3. **Set `PUBLIC_BASE_URL`** in `wrangler.toml` under `[vars]`, or override via Cloudflare dashboard / secrets as your team prefers.

4. Install dependencies:

   ```bash
   npm install
   ```

## Local development

```bash
npm run dev
```

Health check: `GET http://localhost:8787/v1/health` → `{"ok":true}`.

## Deploy

```bash
npm run deploy
```

After deploy, note the Worker URL (e.g. `https://winklo-avatar-upload.<account>.workers.dev`).

## Flutter app configuration

Point the mobile app at the deployed Worker base URL:

```bash
flutter run --dart-define=AVATAR_UPLOAD_BASE_URL=https://winklo-avatar-upload.<account>.workers.dev
```

Use the same define for release builds (CI/Xcode/Android Gradle as applicable).

## Environment

| Name | Source | Purpose |
|------|--------|---------|
| `FIREBASE_PROJECT_ID` | `[vars]` in `wrangler.toml` | Firebase project for ID token verification (Task 5) |
| `PUBLIC_BASE_URL` | `[vars]` | Public R2 URL prefix for served avatars |
| `AVATARS` | R2 binding | `winklo-avatars` bucket |
