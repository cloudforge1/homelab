# Getting Started

Welcome to mVat - a multi-tenant Polish VAT & invoice processing system.

---

## Prerequisites

| Tool    | Version | Purpose         |
|---------|---------|-----------------|
| Node.js | 20+     | Runtime         |
| pnpm    | 9+      | Package manager |
| Docker  | Latest  | Databases       |
| Make    | Any     | Build commands  |

---

## Quick Start

```bash
# 1. Clone and install
git clone <repo>
cd mVat1
pnpm install

# 2. Start databases
make db-up

# 3. Apply migrations
make db-migrate

# 4. Start development
make dev
```

---

## Project URLs

| Service  | URL                   |
|----------|-----------------------|
| Frontend | http://localhost:3000 |
| API      | http://localhost:3044 |
| Swagger  | http://localhost:3040 |

---

## Key Commands

```bash
make setup           # Complete project setup
make dev             # Start development servers
make build           # Production build
make test            # Run all tests
make db-up           # Start Docker databases
make db-migrate      # Apply Prisma migrations
pnpm type-check      # TypeScript validation
```

---

## Project Structure

```
mVat1/
├── src/app/          # React frontend (@mvat/app)
├── src/api/          # NestJS backend (@mvat/api)
├── src/shared/       # Shared library (@mvat/shared)
└── src/prisma/       # Database schemas
```

---

## Next Steps

- [Local Development Guide](./local-development.md)
- [Database Setup](./database-setup.md)
- [Architecture Overview](../adr/ADR_0000_platform/_index.mdx)
