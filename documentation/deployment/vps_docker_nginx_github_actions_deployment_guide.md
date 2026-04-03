# VPS + Docker + Nginx + GitHub Actions Deployment Guide

## Purpose

This document consolidates the earlier discussion about deploying this project's backend from local development to a VPS using Docker, Nginx, a domain, and GitHub Actions. It is written as a practical guide for a first-time deployment.

## Project Context

This repository currently has two main parts:

1. Backend: Laravel API  
   Path: `backend/halal_traceability_api`
2. Frontend: Flutter application  
   Path: `frontend/halal_traceability_app`

From the current codebase:

- The Laravel backend already supports standard mail configuration through `MAIL_*` environment variables.
- The Flutter frontend already supports switching API origin through `--dart-define=API_ORIGIN=...`.
- Password reset email flow already exists in the backend.

This means the project is structurally suitable for moving the backend from local development to a VPS.

## Recommended Deployment Direction

For this project, the recommended route is:

1. Deploy the Laravel backend to a VPS
2. Run it in Docker
3. Put Nginx in front of it
4. Bind it to a real domain and HTTPS
5. Add GitHub Actions for CI/CD

This is preferred over using cPanel for the long term because:

- Docker gives a more consistent runtime environment
- CI/CD integrates naturally with containers
- Nginx reverse proxying is standard and flexible
- Queue workers, scheduled tasks, and future infrastructure are easier to manage
- Versioned deployments and rollbacks become much cleaner

## High-Level Architecture

The target flow looks like this:

`Developer machine -> GitHub -> GitHub Actions -> Container registry -> VPS -> Docker Compose -> Nginx -> Domain -> Client app`

A more concrete view:

1. You write code locally
2. You push code to GitHub
3. GitHub Actions runs tests and builds a Docker image
4. The image is pushed to a container registry such as `ghcr.io`
5. The VPS pulls that image and starts containers
6. Nginx exposes only ports `80` and `443`
7. Your domain such as `api.example.com` points to the VPS
8. The Flutter app calls `https://api.example.com/api`

## Where WSL2 Fits In

Your local WSL2 environment is typically just your control terminal.

The relationship is:

- Windows: your main machine
- WSL2: your Linux terminal environment for development and SSH
- VPS: the actual remote Linux server where the backend runs

In practice:

1. You open WSL2 locally
2. You run `ssh user@your-vps-ip`
3. You log into the remote server
4. Commands executed after login run on the VPS, not on your local WSL2

Example:

```bash
ssh root@123.123.123.123
```

After login, if you run:

```bash
docker ps
```

you are viewing containers running on the VPS.

## Why VPS + Docker Is Better Than "Build Locally and Upload"

It is technically possible to build Docker images locally, export them, upload them to the VPS, and import them there.

However, that is not the ideal long-term flow. A better deployment model is:

1. Define the app using a `Dockerfile`
2. Let GitHub Actions build the image automatically
3. Push the image to a registry
4. Let the VPS pull the image

This is better because:

- It avoids manual packaging and copying
- It fits CI/CD naturally
- The build process becomes reproducible
- Updating and rollback are easier
- Server provisioning becomes simpler

## Components You Need

Before deployment, prepare these:

1. A VPS
   Recommended OS: Ubuntu 22.04 or 24.04
2. A domain
   Example: `api.example.com` for the backend
3. A GitHub repository
4. A container registry
   Recommended: GitHub Container Registry (`ghcr.io`)

## Deployment Phases

Do not try to solve everything at once. The safest route is phased.

### Phase 1: Containerize the Laravel Backend Locally

Goal:

- Laravel runs in Docker locally
- Database connection works
- Environment variables are externalized
- API endpoints respond correctly

Files typically introduced:

- `backend/halal_traceability_api/Dockerfile`
- `docker-compose.yml`
- `deploy/compose/docker-compose.prod.yml`
- Optional Nginx config for local parity

### Phase 2: Manual Deployment to VPS

Goal:

- The same container setup runs on the VPS
- Domain points to the VPS
- HTTPS works
- Mail configuration works
- Database is reachable

At this stage, deployment can still be manual.

### Phase 3: GitHub Actions Builds Images Automatically

Goal:

- Each push to `main` runs backend tests
- A Docker image is built automatically
- The image is pushed to `ghcr.io`

### Phase 4: Automated Deployment

Goal:

- GitHub Actions connects to the VPS through SSH
- It pulls the latest image
- It restarts the services automatically

This is optional at first. It is fine to keep deployment manual until the base system is stable.

## Typical Runtime Services

A production-like deployment usually contains at least:

1. `app`
   The Laravel PHP application
2. `nginx`
   Reverse proxy handling public HTTP/HTTPS
3. `db`
   MySQL or MariaDB, if you choose to run the database in Docker

If the app uses queues, also add:

4. `queue`
   Runs `php artisan queue:work`

If the app uses scheduled tasks, also add:

5. `scheduler`
   Runs the Laravel scheduler loop or cron-based schedule

## How Nginx and the Domain Work

This is the most important routing concept.

The client accesses:

`https://api.example.com`

Internally, Laravel may only be listening on a private container port.

The flow is:

1. The client requests `api.example.com`
2. DNS resolves the domain to the VPS public IP
3. Nginx on the VPS receives the request
4. Nginx forwards the request to the Laravel container over the Docker network
5. Laravel returns the response
6. Nginx sends the response back to the client

Because of this, you usually do not expose your app container directly to the public internet. Instead:

- Public ports open: `80`, `443`
- Internal app ports stay private

This is cleaner and more secure.

## Why Email Should Work Better on the VPS

The Laravel backend already uses standard mail configuration. In production, mail is typically configured through environment variables such as:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.resend.com
MAIL_PORT=587
MAIL_USERNAME=your-username
MAIL_PASSWORD=your-password
MAIL_FROM_ADDRESS=no-reply@example.com
MAIL_FROM_NAME="Halal Traceability"
```

Why VPS deployment helps:

- The backend is always online
- Mail sending happens on the server, not your local machine
- Production environment variables can be managed properly
- Domain-based mail setup is more realistic for actual use

Important caveat:

Deploying to a VPS does not automatically guarantee successful email delivery. In addition to app configuration, you usually need:

- SPF
- DKIM
- DMARC
- Correct sender identity setup in your mail provider

The correct statement is:

Server deployment makes email sending operationally appropriate, but reliable delivery still depends on mail provider and DNS configuration.

## Why Weather API Access Often Improves After Deployment

Moving the backend to a VPS usually helps external API integration because:

- The backend is always reachable
- Requests come from a stable server environment
- You can use a real domain and HTTPS
- You no longer depend on your development machine being on

Still verify:

- API rate limits
- API key restrictions
- IP restrictions
- Domain restrictions
- CORS or mixed-content issues if any calls happen from the frontend

So the improvement is practical, but not automatic by itself.

## Recommended CI/CD Model

For this project, the best early CI/CD model is:

### CI

On every push:

1. Install backend dependencies
2. Run Laravel tests
3. Validate the build

### CD

After CI passes:

1. Build the Docker image
2. Push the image to `ghcr.io`
3. Either:
   - manually SSH into the VPS and pull/restart, or
   - let GitHub Actions SSH into the VPS and deploy automatically

For the first version, a semi-automatic deployment is recommended:

1. GitHub Actions builds and pushes the image
2. You SSH into the VPS manually
3. You run:

```bash
docker compose pull
docker compose up -d
```

This gives you much easier debugging while keeping most of the pipeline automated.

## Practical Step-by-Step Deployment Flow

Below is the recommended order for someone doing this for the first time.

### Step 1: Prepare Production Environment Variables

You need a production `.env` for Laravel. At minimum, this usually includes:

- `APP_NAME`
- `APP_ENV=production`
- `APP_KEY`
- `APP_DEBUG=false`
- `APP_URL=https://api.example.com`
- `DB_*`
- `MAIL_*`
- queue/cache/session settings if used
- any third-party API keys such as weather providers
- any auth/CORS/Sanctum-related settings

Do not commit production secrets into the repository.

### Step 2: Create a Backend Dockerfile

The backend `Dockerfile` defines:

- PHP base image
- required PHP extensions
- Composer dependency installation
- application code copy
- Laravel optimization steps
- runtime process

For production, prefer a real web stack such as:

- `php-fpm + nginx`

Avoid using `php artisan serve` as the production server.

### Step 3: Create Docker Compose Files

The compose file defines how services run together.

Recommended split for this repository:

- local development: `docker-compose.yml`
- production deployment: `deploy/compose/docker-compose.prod.yml`

Possible minimal production setup:

- `app`
- `nginx`
- `db` if database is containerized

Possible expanded setup:

- `app`
- `nginx`
- `db`
- `queue`
- `scheduler`

### Step 4: Validate the Setup Locally

Before touching the VPS, verify locally:

- API responds
- database connection works
- migrations succeed
- file permissions are correct
- `storage` and `bootstrap/cache` are writable
- email sending works with test credentials if available

### Step 5: Provision the VPS

On the VPS, install at least:

- Docker
- Docker Compose plugin
- Git

Optional but common:

- UFW or another firewall
- Fail2ban

### Step 6: Point the Domain to the VPS

In your DNS provider:

- create an `A` record
- point `api.example.com` to the VPS public IP

### Step 7: Put Deployment Files on the VPS

At early stages, you can either:

1. clone the repository onto the VPS
2. or keep only the deployment files there and pull images from the registry

For the first deployment, keeping the repo or deployment config accessible on the VPS is usually easier for troubleshooting.

### Step 8: Create the Production .env on the VPS

This is one of the most important steps.

- Create the real `.env` only on the VPS
- Do not bake secrets into the Docker image
- Do not commit production secrets to GitHub

### Step 9: Start the Containers

If building on the server:

```bash
docker compose up -d --build
```

If pulling prebuilt images:

```bash
docker compose pull
docker compose up -d
```

### Step 10: Configure HTTPS

Typical stack:

- Nginx
- Certbot

The goal is to serve:

`https://api.example.com`

without exposing the application directly.

### Step 11: Point the Frontend to the Production API

The Flutter app already supports API origin override.

Example:

```bash
flutter run --dart-define=API_ORIGIN=https://api.example.com
```

or for build commands, use the same `--dart-define`.

This makes the frontend call the VPS backend instead of local development addresses.

### Step 12: Add GitHub Actions

A useful first workflow:

1. Trigger on push to `main`
2. Install PHP and Composer dependencies
3. Run Laravel tests
4. Build Docker image
5. Push image to `ghcr.io`

### Step 13: Update Process for Future Releases

Once the image pipeline exists, a normal release becomes:

1. Push code to GitHub
2. GitHub Actions builds and pushes a new image
3. On the VPS:

```bash
docker compose pull
docker compose up -d
```

If later automated, GitHub Actions can execute these steps over SSH.

## Manual Deployment vs Automatic Deployment

### Manual Deployment

You manually SSH into the VPS from WSL2 and run deployment commands.

Advantages:

- Easier to debug
- Safer while learning
- Fewer moving parts initially

Typical commands:

```bash
ssh user@your-vps-ip
docker compose pull
docker compose up -d
```

### Automatic Deployment

GitHub Actions automatically connects to the VPS and runs those commands.

Advantages:

- Faster releases
- Less repetitive manual work
- Better long-term workflow

Recommended only after the manual path is already stable.

## Common Deployment Pitfalls

These issues are more common than Docker itself.

### 1. Wrong APP_URL

This can break:

- password reset links
- generated URLs
- email callbacks
- some cross-origin behavior

### 2. CORS or Sanctum Misconfiguration

This matters especially if:

- the frontend runs in a browser
- there are authenticated API requests
- the app uses cookie-based auth

### 3. File Permission Problems

Laravel often needs writable access to:

- `storage`
- `bootstrap/cache`

### 4. Wrong Database Host

Inside Docker, `127.0.0.1` usually refers to the same container, not another service.

If using Compose, the database host is often the service name, for example:

`DB_HOST=db`

### 5. Mail DNS Is Missing

Even if code sends mail correctly, deliverability can fail without:

- SPF
- DKIM
- DMARC

### 6. HTTP/HTTPS Mismatch

Mixed content or redirect issues happen if:

- frontend uses HTTPS
- backend is still configured as HTTP

### 7. Secrets Baked Into Images

Do not put production `.env` values into the Docker image itself.

Inject them at runtime.

## Why cPanel Is Not the Preferred Choice Here

cPanel can be faster only when the goal is simply:

- upload a traditional PHP site
- run it quickly
- avoid infrastructure learning

It becomes less suitable when you want:

- Docker
- CI/CD
- image-based deployment
- cleaner environment parity
- queue workers and scheduled jobs
- modern release workflows

For this project's direction, `VPS + Docker + Nginx + GitHub Actions` is the more appropriate foundation.

## Recommended Implementation Order

To keep the rollout manageable:

1. Containerize only the Laravel backend first
2. Deploy manually to the VPS
3. Make domain and HTTPS stable
4. Verify email and third-party APIs
5. Add GitHub Actions image build
6. Add automatic deployment only after the above is stable

Do not try to complete Docker, Nginx, HTTPS, domain, CI, and full CD all at once.

## Final Recommendation

The proposed plan is viable and appropriate for this project.

The best practical path is:

1. Use your local WSL2 as the management terminal
2. SSH into the VPS
3. Run the Laravel backend in Docker
4. Put Nginx in front of it
5. Expose it through a real domain and HTTPS
6. Add GitHub Actions for test, build, and later deployment automation

This gives you a production-ready path that is much more maintainable than staying on local hosting or trying to stretch cPanel into a workflow it was not designed for.
