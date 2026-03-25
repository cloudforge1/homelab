# Local Development Setup

> Complete guide to setting up NeverEndingJobs for local development.

---

## Prerequisites

- **Node.js 20+** (LTS recommended)
- **pnpm 9+** (package manager)
- **Docker** (for PostgreSQL)
- **Wrangler CLI** (`npm install -g wrangler`)

---

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/your-org/neverendingjobs.git
cd neverendingjobs

# 2. Install dependencies
pnpm install

# 3. Start PostgreSQL
docker compose up -d

# 4. Configure environment
cp .env.example .env
# Edit .env with your values

# 5. Run migrations
pnpm db:migrate

# 6. Seed database (optional)
pnpm db:seed

# 7. Start dev server
pnpm dev
```

---

## Environment Variables

Create `.env` from `.env.example`:

```bash
# Database (local Docker)
DATABASE_URL="postgresql://dev:dev@localhost:5432/neverendingjobs"

# OAuth (get from provider consoles)
GOOGLE_CLIENT_ID="..."
GOOGLE_CLIENT_SECRET="..."
GITHUB_CLIENT_ID="..."
GITHUB_CLIENT_SECRET="..."

# Session secret (generate with: openssl rand -hex 32)
SESSION_SECRET="..."

# App URL
APP_URL="http://localhost:5173"
```

---

## Docker Compose

The project includes a `docker-compose.yml` for local PostgreSQL:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: neverendingjobs
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### Commands

```bash
# Start PostgreSQL
docker compose up -d

# Stop PostgreSQL
docker compose down

# Reset database (delete volume)
docker compose down -v
```

---

## Database Commands

```bash
# Generate migration from schema changes
pnpm db:generate

# Run pending migrations
pnpm db:migrate

# Push schema (dev only, no migration)
pnpm db:push

# Open Drizzle Studio (database GUI)
pnpm db:studio

# Seed with sample data
pnpm db:seed
```

---

## Development Server

```bash
# Start Vite dev server (hot reload)
pnpm dev

# Start with Wrangler (Workers runtime)
pnpm dev:wrangler
```

### Port Allocation

| Service | Port |
|---------|------|
| Vite dev server | 5173 |
| Wrangler dev | 8787 |
| PostgreSQL | 5432 |
| Drizzle Studio | 4983 |

---

## Miniflare (Local Cloudflare)

Wrangler uses Miniflare to emulate Cloudflare services locally:

```bash
# Start with full Cloudflare emulation
pnpm dev:wrangler
```

This provides local versions of:
- **KV** - Session storage
- **R2** - File storage
- **Queues** - Async jobs
- **Hyperdrive** - Connection pooling (disabled locally)

---

## Testing

```bash
# Unit tests
pnpm test

# E2E tests (requires running app)
pnpm test:e2e

# Type check
pnpm typecheck

# Lint
pnpm lint
```

---

## Troubleshooting

### Port Already in Use

```bash
# Find process using port
lsof -i :5173

# Kill process on port
pnpm kill
```

### Database Connection Failed

```bash
# Check Docker is running
docker ps

# Check PostgreSQL logs
docker compose logs postgres

# Reset database
docker compose down -v && docker compose up -d
```

### OAuth Redirect Errors

Ensure OAuth redirect URIs include:
- `http://localhost:5173/auth/callback/google`
- `http://localhost:5173/auth/callback/github`

---

## IDE Setup

### VS Code Extensions

- **Prettier** - Code formatting
- **ESLint** - Linting
- **Tailwind CSS IntelliSense** - Class autocomplete
- **Prisma** (or Drizzle extension when available)

### Settings

The project includes `.vscode/settings.json` with recommended settings.

---

## Next Steps

- [Database Setup](./database-setup.md) - Schema and migrations
- [Cloudflare Deployment](./cloudflare-deployment.md) - Production deploy
