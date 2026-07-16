# leotena-server

Backend API for the Leotena admin panel (`leoadmin`) and consumer app (`leotena`). Admin panel is the only place content is edited; the consumer app only reads from this API.

## Local dev

```bash
npm install
railway run npx prisma migrate dev --name init
railway run npm run seed
railway run npm run dev
```

## Deploy

```bash
railway up --detach
railway domain
```

Env vars: see `.env.example`.
