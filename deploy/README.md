# Deploy Layout

This directory groups production-facing deployment assets so the repository root stays focused on source code and local development.

## Structure

- `compose/`
  Production Docker Compose files used by VPS deployment workflows.

## Current Usage

- Local development still uses [docker-compose.yml](../docker-compose.yml) from the repository root.
- Optional local bind-mount mode uses [docker-compose.dev.yml](../docker-compose.dev.yml).
- Production deployment uses [docker-compose.prod.yml](compose/docker-compose.prod.yml).
- The current public FYP demo can also be exposed from the local machine through Cloudflare Tunnel at `https://halaltrack.shiebindev.com`.
- Backend feature additions such as new API routes only reach the running local Docker API after rebuilding or restarting the `app` and `nginx` services.

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

## Current Cloudflare Tunnel Demo

The current tunnel setup is useful for phone testing and school demonstration before buying or configuring a VPS.

Recommended local flow:

```powershell
docker compose up -d --build
cloudflared tunnel run <your-tunnel-name>
```

Cloudflare public hostname:

```text
https://halaltrack.shiebindev.com -> http://localhost:8000
```

The Flutter APK should then be built with:

```powershell
flutter build apk --release --dart-define=API_ORIGIN=https://halaltrack.shiebindev.com
```

This does not replace the VPS deployment plan. It only provides a temporary public route into the local Docker backend.

## Secrets and Images

- Runtime secrets belong in `.env`, GitHub secrets, VPS environment files, or the CI/CD secret store.
- Do not commit real Brevo SMTP keys, Gemini API keys, database passwords, or VPS SSH keys.
- The backend image build excludes `.env`, logs, cache, and uploaded runtime storage through backend `.dockerignore`.
- GHCR is the automated CI image target. Docker Hub can be used manually by tagging the local image before pushing.

## Current Note

- The Gemini assistant uses backend `.env` values and remains a server-side integration.
- Brevo SMTP is configured through backend `.env` and has been smoke-tested.
- When Laravel routes or service configuration change locally, refresh the running API with:

```powershell
docker compose up -d --build app nginx
```
