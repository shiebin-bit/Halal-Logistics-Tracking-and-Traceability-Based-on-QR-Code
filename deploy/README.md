# Deploy Layout

This directory groups production-facing deployment assets so the repository root stays focused on source code and local development.

## Structure

- `compose/`
  Production Docker Compose files used by VPS deployment workflows.

## Current Usage

- Local development still uses [docker-compose.yml](../docker-compose.yml) from the repository root.
- Optional local bind-mount mode uses [docker-compose.dev.yml](../docker-compose.dev.yml).
- Production deployment uses [docker-compose.prod.yml](compose/docker-compose.prod.yml).

## VPS Expectation

The current CD workflow assumes the VPS contains:

- this repository layout
- a root-level production `.env`
- [docker-compose.prod.yml](compose/docker-compose.prod.yml)
- the backend Nginx config at `backend/halal_traceability_api/docker/nginx/default.conf`

The deploy workflow then runs:

```bash
docker compose --env-file .env -f deploy/compose/docker-compose.prod.yml up -d
```
