# Leotena

Online TV — premium movies, series, and live channels streaming.

This is a monorepo with three parts:

| Path | What it is | Deploys to |
|---|---|---|
| `lib/` (root) | **Leotena** — the consumer Flutter app. Fetches all content (channels, movies, schedule, pricing) from `server/`; never writes to it. | Android / iOS / web |
| `leoadmin/` | **LeoAdmin** — the admin panel Flutter app. The only place content is created/edited. | Web (internal tool) |
| `server/` | Node/Express/Prisma API backed by Postgres. Public read endpoints for the consumer app, JWT-authed admin endpoints for LeoAdmin. | Railway |

## Backend (`server/`)

```bash
cd server
npm install
npx prisma migrate deploy
npm run seed   # first time only
npm run dev
```

See `server/.env.example` for required environment variables.

### Deploying on Railway from this repo

When connecting this repo to a Railway service, set the service's **root directory to `server`** (Railway dashboard → service → Settings → Source) — the backend is a subdirectory of this monorepo, not the repo root.

## Flutter apps

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-backend-url
```

Same for `leoadmin/`.
